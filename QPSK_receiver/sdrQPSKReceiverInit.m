function SimParams = sdrQPSKReceiverInit(platform,address,sampleRate,....
    centerFreq,gain,captureTime,isHDLCompatible,varargin)
%   Copyright 2017-2023 The MathWorks, Inc.

% Parse optional input arguments
p = inputParser;
addParameter(p, 'ShowConstellation', false, @islogical);
parse(p, varargin{:});

%% General simulation parameters
SimParams.Fs              = sampleRate; % Sample rate
SimParams.ModulationOrder = 4; % QPSK alphabet size
SimParams.Interpolation   = 2; % Interpolation factor
SimParams.Decimation      = 1; % Decimation factor
SimParams.Rsym            = sampleRate/SimParams.Interpolation;
SimParams.Tsym            = 1/SimParams.Rsym; % Symbol time in sec

% If HDL compatible, code will not be optimized in performance
if isHDLCompatible
    SimParams.CFCAlgorithm = 'Correlation-Based';
else
    SimParams.CFCAlgorithm = 'FFT-Based';
end

% Constellation diagram parameter
SimParams.ShowConstellation = p.Results.ShowConstellation;

%% Frame Specifications
% [BarkerCode*2 | 'Hello world 000\n' | 'Hello world 001\n' ... | 'Hello world 099\n'];
SimParams.BarkerCode      = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1];     % Bipolar Barker Code
SimParams.BarkerLength    = length(SimParams.BarkerCode);
SimParams.HeaderLength    = SimParams.BarkerLength * 2;                   % Duplicate 2 Barker codes to be as a header
SimParams.Message         = 'Hello world';
SimParams.MessageLength   = length(SimParams.Message) + 5;                % 'Hello world 000\n'...
SimParams.NumberOfMessage = 100;                                          % Number of messages in a frame
SimParams.PayloadLength   = SimParams.NumberOfMessage * SimParams.MessageLength * 7; % 7 bits per characters
SimParams.FrameSize       = (SimParams.HeaderLength + SimParams.PayloadLength) ...
    / log2(SimParams.ModulationOrder);                                    % Frame size in symbols
SimParams.FrameTime       = SimParams.Tsym*SimParams.FrameSize;

%% Rx parameters
SimParams.RolloffFactor     = 0.5;                      % Rolloff Factor of Raised Cosine Filter
SimParams.ScramblerBase     = 2;
SimParams.ScramblerPolynomial           = [1 1 1 0 1];
SimParams.ScramblerInitialConditions    = [0 0 0 0];
SimParams.RaisedCosineFilterSpan = 10;                  % Filter span of Raised Cosine Tx Rx filters (in symbols)
SimParams.DesiredPower                  = 2;            % AGC desired output power (in watts)
SimParams.AveragingLength               = 50;           % AGC averaging length
SimParams.MaxPowerGain                  = 60;           % AGC maximum output power gain
SimParams.MaximumFrequencyOffset        = 6e3;
% Look into model for details for details of PLL parameter choice. 
% Refer equation 7.30 of "Digital Communications - A Discrete-Time Approach" by Michael Rice.
K = 1;
A = 1/sqrt(2);
SimParams.PhaseRecoveryLoopBandwidth    = 0.01;         % Normalized loop bandwidth for fine frequency compensation
SimParams.PhaseRecoveryDampingFactor    = 1;            % Damping Factor for fine frequency compensation
SimParams.TimingRecoveryLoopBandwidth   = 0.01;         % Normalized loop bandwidth for timing recovery
SimParams.TimingRecoveryDampingFactor   = 1;            % Damping Factor for timing recovery
% K_p for Timing Recovery PLL, determined by 2KA^2*2.7 (for binary PAM),
% QPSK could be treated as two individual binary PAM,
% 2.7 is for raised cosine filter with roll-off factor 0.5
SimParams.TimingErrorDetectorGain       = 2.7*2*K*A^2+2.7*2*K*A^2;
SimParams.PreambleDetectionThreshold    = 0.8;

%% BER calculation parameters

% BER calculation masks
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
    % Pluto receiver parameters
    SimParams.PlutoCenterFrequency      = centerFreq;
    SimParams.PlutoGain                 = gain;
    SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
    SimParams.PlutoFrameLength          = SimParams.Interpolation * SimParams.FrameSize;
    SimParams.SDRFrameTime            = SimParams.PlutoFrameLength / SimParams.PlutoFrontEndSampleRate;
else
    % USRP receiver parameters
    switch platform
        case {'B200','B210'}
            SimParams.MasterClockRate = 20e6;  % Hz
        case {'X300','X310'}
            SimParams.MasterClockRate = 200e6; % Hz
        case {'N200/N210/USRP2'}
            SimParams.MasterClockRate = 100e6; % Hz
        case {'N300','N310'}
            SimParams.MasterClockRate = 125e6; % Hz
        case {'N320/N321'}
            SimParams.MasterClockRate = 200e6; % Hz
        otherwise
            error(message('sdru:examples:UnsupportedPlatform', ...
                platform))
    end

    SimParams.USRPCenterFrequency           = centerFreq;
    SimParams.USRPGain                      = gain;
    SimParams.USRPFrontEndSampleRate        = SimParams.Fs; % Nyquist sampling theorem
    SimParams.USRPDecimationFactor          = SimParams.MasterClockRate/SimParams.USRPFrontEndSampleRate;
    SimParams.USRPFrameLength               = SimParams.Interpolation * SimParams.FrameSize;
    SimParams.SDRFrameTime                 = SimParams.USRPFrameLength/SimParams.USRPFrontEndSampleRate;
end

SimParams.StopTime                      = captureTime;