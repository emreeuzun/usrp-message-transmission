classdef (StrictDefaults)QPSKReceiver < matlab.System
% Implements the 16-QAM receiver chain.
properties (Nontunable)
    % Nontunable properties are now passed from the init script
    ModulationOrder = 16;
    SampleRate = 1e6;
    DecimationFactor = 1;
    FrameSize = 2344;
    PayloadLength = 7350;
    PreambleDetectionThreshold = 20;
    DesiredPower = 2;
    AveragingLength = 50;
    MaxPowerGain = 60;
    RolloffFactor = 0.5;
    RaisedCosineFilterSpan = 10;
    InputSamplesPerSymbol = 2;
    MaximumFrequencyOffset = 6e3;
    CFCAlgorithm = 'FFT-Based';
    CFCFrequencyResolution = 1000;
    PostFilterOversampling = 2;
    PhaseRecoveryLoopBandwidth = 0.05; % Artırılmış değer
    PhaseRecoveryDampingFactor = 1;
    TimingRecoveryDampingFactor = 1;
    TimingRecoveryLoopBandwidth = 0.05; % Artırılmış değer
    TimingErrorDetectorGain = 5.4;
    DescramblerBase = 2;
    DescramblerPolynomial = [1 1 1 0 1];
    DescramblerInitialConditions = [0 0 0 0];
    BerMask = [];
    PrintOption = false;
    Preview = false;
    ShowConstellation = false;
end
properties (Access = private)
    pAGC, pRxFilter, pCoarseFreqCompensator, pFineFreqCompensator
    pTimingRec, pFrameSync, pDataDecod, pMeanFreqOff, pCnt
    pCoarseFreqEstimator
    pConstellationFig
    pSignalViewer % Yeni eklendi: Sinyalleri görmek için
    pTimingScope % Yeni eklendi: Zamanlama kurtarma çıktısı için
end
properties (Access = private, Constant)
    % Header'ın nasıl oluşturulacağı burada tanımlanır.
    pModulatedHeader = QPSKReceiver.generateQAM16Header();
end
methods
    function obj = QPSKReceiver(varargin)
        setProperties(obj,nargin,varargin{:});
    end
end
methods (Static, Access = private)
    function header = generateQAM16Header()
        barker = [+1; +1; +1; +1; +1; -1; -1; +1; +1; -1; +1; -1; +1];
        ubc = (barker + 1) / 2;
        header_4bit = repelem(ubc, 4);
        headerBits = repmat(header_4bit, 2, 1);
        modulator = comm.RectangularQAMModulator('ModulationOrder', 16, 'BitInput', true, 'NormalizationMethod', 'UnitAveragePower'); % Normalizasyonu kontrol edin
        header = modulator(headerBits);
    end
end
methods (Access = protected)
    function setupImpl(obj)
        obj.pAGC = comm.AGC('DesiredOutputPower', obj.DesiredPower, ...
            'AveragingLength', obj.AveragingLength, 'MaxPowerGain', obj.MaxPowerGain);
        obj.pRxFilter = comm.RaisedCosineReceiveFilter('RolloffFactor', obj.RolloffFactor, ...
            'FilterSpanInSymbols', obj.RaisedCosineFilterSpan, 'InputSamplesPerSymbol', obj.InputSamplesPerSymbol, ...
            'DecimationFactor', obj.DecimationFactor);
        
        obj.pCoarseFreqEstimator = comm.CoarseFrequencyCompensator('SampleRate', obj.SampleRate/obj.DecimationFactor, ...
            'Algorithm', obj.CFCAlgorithm);
        if strcmpi(obj.CFCAlgorithm,'FFT-Based')
            obj.pCoarseFreqEstimator.FrequencyResolution = obj.CFCFrequencyResolution;
        end
        obj.pCoarseFreqCompensator = comm.PhaseFrequencyOffset('FrequencyOffsetSource', 'Input port', ...
            'SampleRate', obj.SampleRate/obj.DecimationFactor);
        
        obj.pFineFreqCompensator = comm.CarrierSynchronizer('Modulation', 'QAM', ...
            'SamplesPerSymbol', obj.PostFilterOversampling, 'DampingFactor', obj.PhaseRecoveryDampingFactor, ...
            'NormalizedLoopBandwidth', obj.PhaseRecoveryLoopBandwidth); % Ayarlanmış Nontunable değerini kullanır
        
        obj.pTimingRec = comm.SymbolSynchronizer('TimingErrorDetector', 'Gardner (non-data-aided)', ...
            'SamplesPerSymbol', obj.PostFilterOversampling, 'DampingFactor', obj.TimingRecoveryDampingFactor, ...
            'NormalizedLoopBandwidth', obj.TimingRecoveryLoopBandwidth, ... % Ayarlanmış Nontunable değeri kullanır
            'DetectorGain', obj.TimingErrorDetectorGain);
        
        obj.pFrameSync = FrameSynchronizer('Preamble', obj.pModulatedHeader, ...
            'Threshold', obj.PreambleDetectionThreshold, 'OutputLength', obj.FrameSize);
        
        obj.pDataDecod = QPSKDataDecoder('ModulationOrder', obj.ModulationOrder, ...
            'PayloadLength', obj.PayloadLength, 'DescramblerBase', obj.DescramblerBase, ...
            'DescramblerPolynomial', obj.DescramblerPolynomial, 'DescramblerInitialConditions', obj.DescramblerInitialConditions, ...
            'BerMask', obj.BerMask, 'Preview', obj.Preview, 'PrintOption', obj.PrintOption);
            
        obj.pMeanFreqOff = 0;
        obj.pCnt = 0;
        
        if obj.ShowConstellation
            obj.pConstellationFig = comm.ConstellationDiagram('Title', '16-QAM Receiver', ...
                'ReferenceConstellation', qammod(0:15, 16, 'UnitAveragePower', true), ...
                'XLimits', [-2 2], 'YLimits', [-2 2]);
        end

        % Sinyal görselleştiricilerini setupImpl'de başlatın
        obj.pSignalViewer = comm.TimeScope(...
            'SampleRate', obj.SampleRate / obj.DecimationFactor, ...
            'TimeSpan', 1e-3, ... % 1ms zaman aralığı
            'LayoutDimensions', [3 1], ...
            'Title', 'Receiver Signals', ...
            'ShowGrid', true, ...
            'YLimits', [-2 2]);
        obj.pSignalViewer.ActiveDisplay = 1;
        obj.pSignalViewer.YLabel = 'RC Filter Out';
        obj.pSignalViewer.ActiveDisplay = 2;
        obj.pSignalViewer.YLabel = 'Timing Sync Out';
        obj.pSignalViewer.ActiveDisplay = 3;
        obj.pSignalViewer.YLabel = 'Fine Freq Sync Out';

        obj.pTimingScope = comm.TimeScope(...
            'SampleRate', obj.SampleRate / obj.DecimationFactor, ...
            'TimeSpan', 1e-3, ... % 1ms zaman aralığı
            'Title', 'Timing Recovery Error', ...
            'ShowGrid', true, ...
            'YLimits', [-1 1]);
    end
    
    function [RCRxSignal,timingRecSignal,fineCompSignal,BER,output] = stepImpl(obj, bufferSignal)
        AGCSignal = obj.pAGC(bufferSignal);
        RCRxSignal = obj.pRxFilter(AGCSignal);
        [~, freqOffsetEst] = obj.pCoarseFreqEstimator(RCRxSignal);
        % Frekans ofseti tahminini daha dinamik hale getirmek için basit ortalamayı kaldırabilirsiniz
        % Veya daha karmaşık bir filtre kullanabilirsiniz. Şimdilik kalsın.
        freqOffsetEst = (freqOffsetEst + obj.pCnt * obj.pMeanFreqOff)/(obj.pCnt+1);
        obj.pCnt = obj.pCnt + 1;
        obj.pMeanFreqOff = freqOffsetEst;
        
        coarseCompSignal = obj.pCoarseFreqCompensator(RCRxSignal, -freqOffsetEst);
        
        % Zamanlama kurtarma adımında ikinci bir çıktı olan zamanlama hatası sinyalini alın
        [timingRecSignal, timingError] = obj.pTimingRec(coarseCompSignal); 
        
        fineCompSignal = obj.pFineFreqCompensator(timingRecSignal);
        
        % Görselleştirme
        obj.pSignalViewer(RCRxSignal, timingRecSignal, fineCompSignal);
        obj.pTimingScope(timingError); % Zamanlama hatasını görselleştir
        
        if obj.ShowConstellation
            obj.pConstellationFig(fineCompSignal);
        end
        
        % pFrameSync'in çıktısının boyut ve tipini sabitle
        symFrame = complex(zeros(obj.FrameSize, 1)); % Initialize symFrame to a fixed size and type
        isFrameValid = false; % Initialize isFrameValid
        
        [detectedFrame, frameDetectedFlag] = obj.pFrameSync(fineCompSignal);
        
        if frameDetectedFlag % Eğer geçerli bir çerçeve bulunduysa
            if length(detectedFrame) == obj.FrameSize
                symFrame = detectedFrame;
                isFrameValid = frameDetectedFlag;
            else
                warning('QPSKReceiver:FrameSizeMismatch', 'FrameSynchronizer returned a frame of unexpected size. Continuing with zeros.');
                % symFrame ve isFrameValid başlangıç değerlerinde kalır (zeros ve false).
            end
        end
        
        [BER, output] = obj.pDataDecod(symFrame, isFrameValid);
    end

    function releaseImpl(obj)
        % Kaynakları serbest bırakın
        release(obj.pAGC);
        release(obj.pRxFilter);
        release(obj.pCoarseFreqCompensator);
        release(obj.pFineFreqCompensator);
        release(obj.pTimingRec);
        release(obj.pFrameSync);
        release(obj.pDataDecod);
        release(obj.pCoarseFreqEstimator);
        if obj.ShowConstellation && isvalid(obj.pConstellationFig)
            release(obj.pConstellationFig);
        end
        % Yeni eklenen görselleştiricileri serbest bırakın
        if isvalid(obj.pSignalViewer)
            release(obj.pSignalViewer);
        end
        if isvalid(obj.pTimingScope)
            release(obj.pTimingScope);
        end
    end
end
end