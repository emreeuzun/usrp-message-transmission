classdef QPSKDataDecoder < matlab.System
% 16-QAM veri akışını çözer.
properties (Nontunable)
    ModulationOrder = 16;
    PayloadLength = 7350; % Bu, çözülen bitlerin beklenen maksimum uzunluğudur.
    DescramblerBase = 2;
    DescramblerPolynomial = [1 1 1 0 1];
    DescramblerInitialConditions = [0 0 0 0];
    BerMask = [];
    PrintOption = false;
    Preview = false;
end
properties (Access = private)
    pQAMDemodulator, pDescrambler, pErrorRateCalc, pTargetBits, pBER
end
properties (Constant, Access = private)
    pModulatedHeader = QPSKDataDecoder.generateQAM16Header();
    % Başlık uzunluğu BİT cinsinden sabit olarak tanımlandı.
    HEADER_LENGTH_BITS = 104; % (13 Barker sembolü * 2 tekrarlama * 4 bit/sembol (16-QAM)) = 104 bit
end
methods
    function obj = QPSKDataDecoder(varargin)
        setProperties(obj,nargin,varargin{:});
    end
end
methods (Static, Access = private)
    function header = generateQAM16Header()
        barker = [+1; +1; +1; +1; +1; -1; -1; +1; +1; -1; +1; -1; +1];
        ubc = (barker + 1) / 2;
        header_4bit = repelem(ubc, 4);
        headerBits = repmat(header_4bit, 2, 1);
        % BURAYI KONTROL EDİN: Normalizasyon metodunu verici ile eşleştirin.
        modulator = comm.RectangularQAMModulator('ModulationOrder', 16, 'BitInput', true, 'NormalizationMethod', 'UnitAveragePower'); 
        header = modulator(headerBits);
    end
end
methods (Access = protected)
    function setupImpl(obj)
        % BURAYI KONTROL EDİN: Demodülatör normalizasyonunu verici ile eşleştirin.
        obj.pQAMDemodulator = comm.RectangularQAMDemodulator('ModulationOrder', obj.ModulationOrder, ...
            'BitOutput', true, 'NormalizationMethod', 'UnitAveragePower'); 
        
        obj.pDescrambler = comm.Descrambler(obj.DescramblerBase, ...
            obj.DescramblerPolynomial, obj.DescramblerInitialConditions);
        
        obj.pErrorRateCalc = comm.ErrorRate('Samples', 'Custom', 'CustomSamples', obj.BerMask);
        
        msgStr = 'Hello world';
        msgLen = length(msgStr) + 5; 
        numMsgs = floor(obj.PayloadLength / (msgLen*7)); 
        
        msgSet = zeros(numMsgs * msgLen, 1, 'int8');
        for msgCnt = 0 : numMsgs - 1
            char_array = sprintf('%s %03d\n', msgStr, mod(msgCnt, 100));
            msgSet(msgCnt * msgLen + (1:length(char_array))) = int8(char_array);
        end
        
        target_bits_matrix = de2bi(msgSet, 7, 'left-msb')';
        obj.pTargetBits = int8(target_bits_matrix(:)); 
    end
    
    function  [BER,output] = stepImpl(obj, data, isValid)
        output = zeros(obj.PayloadLength, 1, 'int8'); 
        BER = obj.pBER; 
        
        if isValid
            headerLengthSymbols = length(obj.pModulatedHeader);
            phaseEst = angle(mean(conj(obj.pModulatedHeader) .* data(1:headerLengthSymbols)));
            
            phShiftedData = data .* exp(-1i*phaseEst);
            demodOut = obj.pQAMDemodulator(phShiftedData);
            
            actualPayloadBitsLen = min(length(demodOut) - obj.HEADER_LENGTH_BITS, obj.PayloadLength);
            if actualPayloadBitsLen < 1
                 % Geçerli bir payload biti yoksa, işlem yapmadan çık
                 % output ve BER önceden başlatıldığı gibi kalır.
                 return; 
            end
            payloadBits = demodOut(obj.HEADER_LENGTH_BITS + 1 : obj.HEADER_LENGTH_BITS + actualPayloadBitsLen);
            
            deScrData_double = obj.pDescrambler(payloadBits);
            deScrData = int8(deScrData_double);
            
            if obj.Preview
                copyLen = min(length(deScrData), obj.PayloadLength);
                output(1:copyLen) = deScrData(1:copyLen);
            elseif obj.PrintOption
                charSet = int8(bi2de(reshape(deScrData, 7, [])', 'left-msb'));
                fprintf('%s', char(charSet));
            end
            
            len = min(length(obj.pTargetBits), length(deScrData));
            obj.pBER = obj.pErrorRateCalc(obj.pTargetBits(1:len), deScrData(1:len));
            BER = obj.pBER; 
        end
    end
    
    function releaseImpl(obj)
        release(obj.pQAMDemodulator);
        release(obj.pDescrambler);
        release(obj.pErrorRateCalc);
    end

    function resetImpl(obj)
        reset(obj.pQAMDemodulator);
        reset(obj.pDescrambler);
        reset(obj.pErrorRateCalc);
        obj.pBER = zeros(3, 1);
    end
end
end