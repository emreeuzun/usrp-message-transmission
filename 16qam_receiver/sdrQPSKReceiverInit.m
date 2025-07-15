function SimParams = sdrQPSKReceiverInit(platform,address,sampleRate,....
    centerFreq,gain,captureTime,isHDLCompatible,varargin)
% Initialize parameters for the 16-QAM receiver.

% Parse optional input arguments
p = inputParser;
addParameter(p, 'ShowConstellation', false, @islogical);
parse(p, varargin{:});

%% General simulation parameters
SimParams.Fs              = sampleRate;
SimParams.ModulationOrder = 16;
SimParams.Interpolation   = 2;
SimParams.Decimation      = 1;
SimParams.Rsym            = sampleRate/SimParams.Interpolation;
SimParams.Tsym            = 1/SimParams.Rsym;

if isHDLCompatible
    SimParams.CFCAlgorithm = 'Correlation-Based';
else
    SimParams.CFCAlgorithm = 'FFT-Based';
end

SimParams.ShowConstellation = p.Results.ShowConstellation;

%% Frame Specifications
SimParams.BarkerCode      = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1]';
SimParams.BarkerLength    = length(SimParams.BarkerCode);
% DÜZELTME: Başlık uzunluğu BİT cinsinden doğru hesaplandı (13 eleman * 2 tekrar * 4 bit/sembol)
SimParams.HeaderLength    = SimParams.BarkerLength * 2 * 4; % = 104 bit
SimParams.Message         = 'Hello world';
SimParams.MessageLength   = length(SimParams.Message) + 5;
SimParams.NumberOfMessage = 100;
SimParams.PayloadLength   = SimParams.NumberOfMessage * SimParams.MessageLength * 7;
% DÜZELTME: Çerçeve boyutu (sembol cinsinden) doğru başlık uzunluğuna göre hesaplanıyor
SimParams.FrameSize       = (SimParams.HeaderLength + SimParams.PayloadLength) / log2(SimParams.ModulationOrder);
SimParams.FrameTime       = SimParams.Tsym*SimParams.FrameSize;

%% Rx parameters
SimParams.RolloffFactor                 = 0.5;
SimParams.ScramblerBase                 = 2;
SimParams.ScramblerPolynomial           = [1 1 1 0 1];
SimParams.ScramblerInitialConditions    = [0 0 0 0];
SimParams.RaisedCosineFilterSpan        = 10;
SimParams.DesiredPower                  = 2;
SimParams.AveragingLength               = 50;
SimParams.MaxPowerGain                  = 60;
SimParams.MaximumFrequencyOffset        = 6e3;
SimParams.PhaseRecoveryLoopBandwidth    = 0.01;
SimParams.PhaseRecoveryDampingFactor    = 1;
SimParams.TimingRecoveryLoopBandwidth   = 0.01;
SimParams.TimingRecoveryDampingFactor   = 1;
K = 1; A = 1/sqrt(2);
SimParams.TimingErrorDetectorGain       = 2.7*2*K*A^2*2;
SimParams.PreambleDetectionThreshold    = 20; % 16-QAM başlığı için eşik değeri artırıldı

%% BER calculation parameters
SimParams.BerMask = zeros(SimParams.NumberOfMessage * length(SimParams.Message) * 7, 1);
for i = 1 : SimParams.NumberOfMessage
    SimParams.BerMask( (i-1) * length(SimParams.Message) * 7 + ( 1: length(SimParams.Message) * 7) ) = ...
        (i-1) * SimParams.MessageLength * 7 + (1: length(SimParams.Message) * 7);
end

%% SDR receiver parameters
SimParams.Platform                      = platform;
SimParams.Address                       = address;
SimParams.IsPluto                       = strcmpi(platform, 'ADALM-PLUTO');

if SimParams.IsPluto
    SimParams.PlutoCenterFrequency      = centerFreq;
    SimParams.PlutoGain                 = gain;
    SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
    SimParams.PlutoFrameLength          = SimParams.Interpolation * SimParams.FrameSize;
    SimParams.SDRFrameTime              = SimParams.PlutoFrameLength / SimParams.PlutoFrontEndSampleRate;
else
    switch platform
        case {'B200','B210'}, SimParams.MasterClockRate = 20e6;
        case {'X300','X310'}, SimParams.MasterClockRate = 200e6;
        case {'N200/N210/USRP2'}, SimParams.MasterClockRate = 100e6;
        case {'N300','N310'}, SimParams.MasterClockRate = 125e6;
        case {'N320/N321'}, SimParams.MasterClockRate = 200e6;
        otherwise, error(message('sdru:examples:UnsupportedPlatform', platform))
    end
    SimParams.USRPCenterFrequency           = centerFreq;
    SimParams.USRPGain                      = gain;
    SimParams.USRPFrontEndSampleRate        = SimParams.Fs;
    SimParams.USRPDecimationFactor          = SimParams.MasterClockRate/SimParams.USRPFrontEndSampleRate;
    SimParams.USRPFrameLength               = SimParams.Interpolation * SimParams.FrameSize;
    SimParams.SDRFrameTime                  = SimParams.USRPFrameLength/SimParams.USRPFrontEndSampleRate;
end

SimParams.StopTime                      = captureTime;
end