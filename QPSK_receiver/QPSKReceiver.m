classdef (StrictDefaults)QPSKReceiver < matlab.System
    %

    % Copyright 2012-2023 The MathWorks, Inc.
    
    properties (Nontunable)
        ModulationOrder = 4;
        SampleRate = 200000;
        DecimationFactor = 1;
        FrameSize = 1133;
        HeaderLength = 13;
        NumberOfMessage = 20;
        PayloadLength = 2240;
        DesiredPower = 2
        AveragingLength = 50
        MaxPowerGain = 20
        RolloffFactor = 0.5
        RaisedCosineFilterSpan = 10
        InputSamplesPerSymbol = 2
        MaximumFrequencyOffset = 6e3
        CFCFrequencyResolution = 1000
        CFCAlgorithm = 'Correlation-based'
        PostFilterOversampling = 2;
        PhaseRecoveryLoopBandwidth = 0.01;
        PhaseRecoveryDampingFactor = 1;
        TimingRecoveryDampingFactor = 1;
        TimingRecoveryLoopBandwidth = 0.01;
        TimingErrorDetectorGain = 5.4;
        PreambleDetectionThreshold = 8;
        DescramblerBase = 2;
        DescramblerPolynomial = [1 1 1 0 1];
        DescramblerInitialConditions = [0 0 0 0];
        BerMask = [];
        PrintOption = false;
        Preview = false;
        ShowConstellation = false; % Yeni parametre: Constellation diagram göster
    end
    
    properties (Access = private)
        pAGC
        pRxFilter
        pCoarseFreqEstimator
        pCoarseFreqCompensator
        pFineFreqCompensator
        pTimingRec
        pFrameSync
        pDataDecod
        pMeanFreqOff
        pCnt
        % Constellation diagram için yeni özellikler
        pConstellationBuffer
        pConstellationFig
        pConstellationPlot
        pUpdateCounter
        pBufferSize
    end
    
    properties (Access = private, Constant)
        pUpdatePeriod = 4 % Defines the size of vector that will be processed in AGC system object
        % Doğru QPSK modulated header (45°, 135°, 225°, 315° pozisyonlarında)
        pModulatedHeader = (1/sqrt(2)) * (-1-1i) * [+1; +1; +1; +1; +1; -1; -1; +1; +1; -1; +1; -1; +1];
        pMessage = 'Hello world';
        pMessageLength = 16;
    end
    
    methods
        function obj = QPSKReceiver(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access = protected)
        function setupImpl(obj, ~)
            
            obj.pAGC = comm.AGC( ...
                'DesiredOutputPower',       obj.DesiredPower, ...
                'AveragingLength',          obj.AveragingLength, ...
                'MaxPowerGain',             obj.MaxPowerGain);
            
            obj.pRxFilter = comm.RaisedCosineReceiveFilter( ...
                'RolloffFactor',            obj.RolloffFactor, ...
                'FilterSpanInSymbols',      obj.RaisedCosineFilterSpan, ...
                'InputSamplesPerSymbol',    obj.InputSamplesPerSymbol, ...
                'DecimationFactor',         obj.DecimationFactor);
            
            obj.pCoarseFreqEstimator = comm.CoarseFrequencyCompensator( ...
                'Modulation',               'QPSK', ...
                'Algorithm',                obj.CFCAlgorithm, ...
                'SampleRate',               obj.SampleRate/obj.DecimationFactor);

            if strcmpi(obj.CFCAlgorithm,'FFT-Based')
                obj.pCoarseFreqEstimator.FrequencyResolution = obj.CFCFrequencyResolution;
            else
                obj.pCoarseFreqEstimator.MaximumFrequencyOffset = obj.MaximumFrequencyOffset;
            end
            
            obj.pCoarseFreqCompensator = comm.PhaseFrequencyOffset( ...
                'PhaseOffset',              0, ...
                'FrequencyOffsetSource',    'Input port', ...
                'SampleRate',               obj.SampleRate/obj.DecimationFactor);

            obj.pMeanFreqOff = 0;
            
            obj.pCnt = 0;
            
            obj.pFineFreqCompensator = comm.CarrierSynchronizer( ...
                'Modulation',               'QPSK', ...
                'ModulationPhaseOffset',    'Auto', ...
                'SamplesPerSymbol',         obj.PostFilterOversampling, ...
                'DampingFactor',            obj.PhaseRecoveryDampingFactor, ...
                'NormalizedLoopBandwidth',  obj.PhaseRecoveryLoopBandwidth);
            
            obj.pTimingRec = comm.SymbolSynchronizer( ...
                'TimingErrorDetector',      'Gardner (non-data-aided)', ...
                'SamplesPerSymbol',         obj.PostFilterOversampling, ...
                'DampingFactor',            obj.TimingRecoveryDampingFactor, ...
                'NormalizedLoopBandwidth',  obj.TimingRecoveryLoopBandwidth, ...
                'DetectorGain',             obj.TimingErrorDetectorGain);
            
            obj.pFrameSync = FrameSynchronizer( ...
                'Preamble',                 obj.pModulatedHeader, ...
                'Threshold',                obj.PreambleDetectionThreshold, ...
                'OutputLength',             obj.FrameSize);
            
            obj.pDataDecod = QPSKDataDecoder( ...
                'ModulationOrder',          obj.ModulationOrder, ...
                'HeaderLength',             obj.HeaderLength, ...
                'NumberOfMessage',          obj.NumberOfMessage, ...
                'PayloadLength',            obj.PayloadLength, ...
                'DescramblerBase',          obj.DescramblerBase, ...
                'DescramblerPolynomial',    obj.DescramblerPolynomial, ...
                'DescramblerInitialConditions', obj.DescramblerInitialConditions, ...
                'BerMask',                  obj.BerMask, ...
                'Preview',                  obj.Preview, ...
                'PrintOption',              obj.PrintOption);
                
            % Constellation diagram için setup
            if obj.ShowConstellation
                obj.pBufferSize = 1000; % Buffer boyutu
                obj.pConstellationBuffer = complex(zeros(obj.pBufferSize, 1));
                obj.pUpdateCounter = 0;
                
                % Figure oluştur
                obj.pConstellationFig = figure('Name', 'QPSK Constellation Diagram', ...
                    'NumberTitle', 'off', 'Position', [100 100 600 600]);
                
                % Plot setup
                obj.pConstellationPlot = scatter([], [], 'filled', 'MarkerFaceAlpha', 0.6);
                hold on;
                
                % Ideal QPSK constellation noktalarını göster (45°, 135°, 225°, 315°)
                ideal_qpsk = [2+2i, -2+2i, -2-2i, 2-2i] / sqrt(2);
                plot(real(ideal_qpsk), imag(ideal_qpsk), 'ro', 'MarkerSize', 10, ...
                    'LineWidth', 2, 'DisplayName', 'Ideal QPSK');
                
                grid on;
                axis equal;
                xlim([-2 2]);
                ylim([-2 2]);
                xlabel('In-phase (I)');
                ylabel('Quadrature (Q)');
                title('QPSK Constellation Diagram');
                legend('Received Symbols', 'Ideal QPSK', 'Location', 'best');
                drawnow;
            end
        end
        
        function [RCRxSignal,timingRecSignal,fineCompSignal,BER,output] = stepImpl(obj, bufferSignal)
            
            AGCSignal = obj.pAGC(bufferSignal);                          % AGC control
            RCRxSignal = obj.pRxFilter(AGCSignal);                       % Pass the signal through
                                                                         % Square-Root Raised Cosine Received Filter
            [~, freqOffsetEst] = obj.pCoarseFreqEstimator(RCRxSignal);   % Coarse frequency offset estimation
            % average coarse frequency offset estimate, so that carrier
            % sync is able to lock/converge
            freqOffsetEst = (freqOffsetEst + obj.pCnt * obj.pMeanFreqOff)/(obj.pCnt+1);
            obj.pCnt = obj.pCnt + 1;            % update state
            obj.pMeanFreqOff = freqOffsetEst;
            
            coarseCompSignal = obj.pCoarseFreqCompensator(RCRxSignal,...
                -freqOffsetEst);                                         % Coarse frequency compensation
            timingRecSignal = obj.pTimingRec(coarseCompSignal);          % Symbol timing recovery
            
            fineCompSignal = obj.pFineFreqCompensator(timingRecSignal);  % Fine frequency compensation
            
            % Constellation diagram güncelle
            if obj.ShowConstellation && ~isempty(fineCompSignal)
                obj.updateConstellation(fineCompSignal);
            end
            
            [symFrame, isFrameValid] = obj.pFrameSync(fineCompSignal);   % Frame synchronization
            
            [BER, output] = obj.pDataDecod(symFrame, isFrameValid);
            
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
            reset(obj.pAGC);
            reset(obj.pRxFilter);
            reset(obj.pCoarseFreqEstimator);
            reset(obj.pCoarseFreqCompensator);
            reset(obj.pFineFreqCompensator);
            reset(obj.pTimingRec);
            reset(obj.pFrameSync);
            reset(obj.pDataDecod);
            obj.pMeanFreqOff = 0;
            obj.pCnt = 0;
            
            % Constellation diagram reset
            if obj.ShowConstellation
                obj.pUpdateCounter = 0;
                if ~isempty(obj.pConstellationBuffer)
                    obj.pConstellationBuffer = complex(zeros(obj.pBufferSize, 1));
                end
            end
        end
        
        function releaseImpl(obj)
            release(obj.pAGC);
            release(obj.pRxFilter);
            release(obj.pCoarseFreqEstimator);
            release(obj.pCoarseFreqCompensator);
            release(obj.pFineFreqCompensator);
            release(obj.pTimingRec);
            release(obj.pFrameSync);
            release(obj.pDataDecod);
            
            % Constellation figure'ı kapat
            if obj.ShowConstellation && ~isempty(obj.pConstellationFig) && isvalid(obj.pConstellationFig)
                close(obj.pConstellationFig);
            end
        end
        
        function N = getNumOutputsImpl(~)
            N = 5;
        end
    end
end