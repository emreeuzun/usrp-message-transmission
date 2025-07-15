classdef (StrictDefaults)QAM16Transmitter < matlab.System  
%#codegen
% Generates the 16-QAM signal to be transmitted
    
%   Modified from QPSKTransmitter for 16-QAM
    
    properties (Nontunable)
        UpsamplingFactor = 2;
        ScramblerBase = 2;
        ScramblerPolynomial = [1 1 1 0 1];
        ScramblerInitialConditions = [0 0 0 0];
        RolloffFactor = 0.5
        RaisedCosineFilterSpan = 10
        NumberOfMessage = 100
        MessageLength = 16
        MessageBits = []
        ModulationOrder = 16; % 16-QAM
        ShowConstellation = false; % Constellation diagram göster
    end
    
    properties (Access=private)
        pBitGenerator
        pQAM16Modulator 
        pTransmitterFilter
        pMessage = 'Hello world';
        pHeader = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1]; % Bipolar barker-code
        % Constellation diagram için
        pConstellationBuffer
        pConstellationFig
        pConstellationPlot
        pUpdateCounter
        pBufferSize
    end
    
    methods
        function obj = QAM16Transmitter(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj)
            obj.pBitGenerator = QAM16BitsGenerator( ...
                'NumberOfMessage',              obj.NumberOfMessage, ...
                'MessageLength',                obj.MessageLength, ...
                'MessageBits',                  obj.MessageBits, ...
                'ScramblerBase',                obj.ScramblerBase, ...
                'ScramblerPolynomial',          obj.ScramblerPolynomial, ...
                'ScramblerInitialConditions',   obj.ScramblerInitialConditions);
            
            % 16-QAM Modulator - receiver ile aynı ayarları kullan
            obj.pQAM16Modulator = comm.RectangularQAMModulator( ...
                'ModulationOrder',              obj.ModulationOrder, ...
                'BitInput',                     true, ...
                'NormalizationMethod',          'Average power', ...
                'OutputDataType',               'double');
            
            obj.pTransmitterFilter = comm.RaisedCosineTransmitFilter( ...
                'RolloffFactor',                obj.RolloffFactor, ...
                'FilterSpanInSymbols',          obj.RaisedCosineFilterSpan, ...
                'OutputSamplesPerSymbol',       obj.UpsamplingFactor);
                
            % Constellation diagram için setup
            if obj.ShowConstellation
                obj.pBufferSize = 1000; % Buffer boyutu
                obj.pConstellationBuffer = complex(zeros(obj.pBufferSize, 1));
                obj.pUpdateCounter = 0;
                
                % Figure oluştur
                obj.pConstellationFig = figure('Name', '16-QAM Transmitter Constellation', ...
                    'NumberTitle', 'off', 'Position', [750 100 600 600]);
                
                % Plot setup
                obj.pConstellationPlot = scatter([], [], 'filled', 'MarkerFaceAlpha', 0.6, ...
                    'MarkerFaceColor', 'green');
                hold on;
                
                % Ideal 16-QAM constellation noktalarını göster
                M = 16;
                grayIndices = 0:M-1;
                symbolMap = qammod(grayIndices, M, 'UnitAveragePower', true);
                
                plot(real(symbolMap), imag(symbolMap), 'ro', 'MarkerSize', 8, ...
                    'LineWidth', 2, 'DisplayName', 'Ideal 16-QAM');
                
                grid on;
                axis equal;
                xlim([-1.5 1.5]);
                ylim([-1.5 1.5]);
                xlabel('In-phase (I)');
                ylabel('Quadrature (Q)');
                title('16-QAM Transmitter Constellation Diagram');
                legend('Transmitted Symbols', 'Ideal 16-QAM', 'Location', 'best');
                drawnow;
            end
        end

        function transmittedSignal = stepImpl(obj) 
            [transmittedBin, ~] = obj.pBitGenerator();                 % Generates the data to be transmitted
            modulatedData = obj.pQAM16Modulator(transmittedBin);       % Modulates the bits into 16-QAM symbols
            
            % Constellation diagram güncelle (modulated data'yı göster)
            if obj.ShowConstellation && ~isempty(modulatedData)
                obj.updateConstellation(modulatedData);
            end
            
            transmittedSignal = obj.pTransmitterFilter(modulatedData); % Square root Raised Cosine Transmit Filter
        end
        
        function updateConstellation(obj, signal)
            % Constellation buffer'ı güncelle
            signalLength = length(signal);
            
            if signalLength >= obj.pBufferSize
                % Eğer gelen signal buffer'dan büyükse, son pBufferSize kadar sample al
                obj.pConstellationBuffer = signal(end-obj.pBufferSize+1:end);
            else
                % Buffer'ı kaydır ve yeni örnekleri ekle
                obj.pConstellationBuffer(1:end-signalLength) = ...
                    obj.pConstellationBuffer(signalLength+1:end);
                obj.pConstellationBuffer(end-signalLength+1:end) = signal;
            end
            
            % Her 10 frame'de bir güncelle (performance için)
            obj.pUpdateCounter = obj.pUpdateCounter + 1;
            if mod(obj.pUpdateCounter, 10) == 0
                try
                    if isvalid(obj.pConstellationFig)
                        % Sadece sıfır olmayan değerleri plot et
                        validSamples = obj.pConstellationBuffer(obj.pConstellationBuffer ~= 0);
                        if ~isempty(validSamples)
                            set(obj.pConstellationPlot, ...
                                'XData', real(validSamples), ...
                                'YData', imag(validSamples));
                            drawnow limitrate;
                        end
                    end
                catch
                    % Figure kapatılmışsa hata vermemesi için
                end
            end
        end
        
        function resetImpl(obj)
            reset(obj.pBitGenerator);
            reset(obj.pQAM16Modulator);
            reset(obj.pTransmitterFilter);
            
            % Constellation diagram reset
            if obj.ShowConstellation
                obj.pUpdateCounter = 0;
                if ~isempty(obj.pConstellationBuffer)
                    obj.pConstellationBuffer = complex(zeros(obj.pBufferSize, 1));
                end
            end
        end
        
        function releaseImpl(obj)
            release(obj.pBitGenerator);
            release(obj.pQAM16Modulator);
            release(obj.pTransmitterFilter);
            
            % Constellation figure'ı kapat
            if obj.ShowConstellation && ~isempty(obj.pConstellationFig) && isvalid(obj.pConstellationFig)
                close(obj.pConstellationFig);
            end
        end
        
        function N = getNumInputsImpl(~)
            N = 0;
        end
    end
end