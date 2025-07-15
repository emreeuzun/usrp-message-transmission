function SimParams = sdrQAM16TransmitterInit(platform,address,sampleRate,....
    centerFreq,gain,captureTime,varargin)
%   Modified from sdrQPSKTransmitterInit for 16-QAM
%   Copyright 2012-2023 The MathWorks, Inc.

% Parse optional input arguments
p = inputParser;
addParameter(p, 'ShowConstellation', false, @islogical);
parse(p, varargin{:});

%% General simulation parameters
SimParams.ModulationOrder = 16; % 16-QAM alphabet size
SimParams.Interpolation   = 2; % Interpolation factor
SimParams.Decimation      = 1; % Decimation factor
SimParams.Fs              = sampleRate; % Sample rate
SimParams.Rsym            = sampleRate/SimParams.Interpolation; % Symbol rate in Hertz
SimParams.Tsym            = 1/SimParams.Rsym; % Symbol time in sec

% Constellation diagram parameter
SimParams.ShowConstellation = p.Results.ShowConstellation;

%% Frame Specifications
% [BarkerCode*2 | 'Hello world 000\n' | 'Hello world 001\n' ...];
SimParams.BarkerCode      = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1];     % Bipolar Barker Code
SimParams.BarkerLength    = length(SimParams.BarkerCode);
SimParams.HeaderLength    = SimParams.BarkerLength * 2 * 4;               % Duplicate 2 Barker codes * 4 bits per symbol for 16-QAM
SimParams.Message         = 'Hello world';
SimParams.MessageLength   = length(SimParams.Message) + 5;                % 'Hello world 000\n'...
SimParams.NumberOfMessage = 100;                                          % Number of messages in a frame

SimParams.PayloadLength   = SimParams.NumberOfMessage * SimParams.MessageLength * 7; % 7 bits per characters
SimParams.FrameSize       = (SimParams.HeaderLength + SimParams.PayloadLength) ...
    / log2(SimParams.ModulationOrder);                                    % Frame size in symbols (4 bits per symbol for 16-QAM)
SimParams.FrameTime       = SimParams.Tsym*SimParams.FrameSize;

%% Tx parameters
SimParams.RolloffFactor     = 0.5;                                        % Rolloff Factor of Raised Cosine Filter
SimParams.ScramblerBase     = 2;
SimParams.ScramblerPolynomial           = [1 1 1 0 1];
SimParams.ScramblerInitialConditions    = [0 0 0 0];
SimParams.RaisedCosineFilterSpan = 10; % Filter span of Raised Cosine Tx Rx filters (in symbols)

%% Message generation
msgSet = zeros(100 * SimParams.MessageLength, 1); 
for msgCnt = 0 : 99
    msgSet(msgCnt * SimParams.MessageLength + (1 : SimParams.MessageLength)) = ...
        sprintf('%s %03d\n', SimParams.Message, msgCnt);
end
bits = de2bi(msgSet, 7, 'left-msb')';
SimParams.MessageBits = bits(:);

%% SDR transmitter parameters
SimParams.Platform                      = platform;
SimParams.Address                       = address;
SimParams.IsPluto                       = strcmpi(platform, 'ADALM-PLUTO');

if SimParams.IsPluto
    % Pluto transmitter parameters
    SimParams.PlutoCenterFrequency      = centerFreq;
    SimParams.PlutoGain                 = gain;
    SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
    SimParams.PlutoFrameLength          = SimParams.Interpolation * SimParams.FrameSize;
    SimParams.SDRFrameTime = SimParams.PlutoFrameLength / SimParams.PlutoFrontEndSampleRate;
else
    % USRP transmitter parameters
    switch platform
        case {'B200','B210'}
            SimParams.MasterClockRate = 20e6;           % Hz
        case {'X300','X310'}
            SimParams.MasterClockRate = 200e6;          % Hz
        case {'N300','N310'}
            SimParams.MasterClockRate = 125e6;          % Hz
        case {'N320/N321'}
            SimParams.MasterClockRate = 200e6;          % Hz
        case {'N200/N210/USRP2'}
            SimParams.MasterClockRate = 100e6;          % Hz
        otherwise
            error(message('sdru:examples:UnsupportedPlatform', ...
                platform))
    end
    SimParams.USRPCenterFrequency       = centerFreq;
    SimParams.USRPGain                  = gain;
    SimParams.USRPFrontEndSampleRate    = SimParams.Rsym * 2; % Nyquist sampling theorem
    SimParams.USRPInterpolationFactor   = SimParams.MasterClockRate/SimParams.USRPFrontEndSampleRate;
    SimParams.USRPFrameLength           = SimParams.Interpolation * SimParams.FrameSize;
    SimParams.SDRFrameTime = SimParams.USRPFrameLength/SimParams.USRPFrontEndSampleRate;
end

SimParams.StopTime = captureTime;