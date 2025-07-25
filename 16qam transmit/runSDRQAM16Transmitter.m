function underrun = runSDRQAM16Transmitter(prmQAM16Transmitter)
%#codegen
%   Modified from runSDRQPSKTransmitter for 16-QAM

%   Copyright 2012-2023 The MathWorks, Inc.

persistent qam16Tx radio
if isempty(qam16Tx)
    % Initialize the components
    % Create and configure the transmitter System object
    qam16Tx = QAM16Transmitter(...
        'UpsamplingFactor',             prmQAM16Transmitter.Interpolation, ...
        'RolloffFactor',                prmQAM16Transmitter.RolloffFactor, ...
        'RaisedCosineFilterSpan',       prmQAM16Transmitter.RaisedCosineFilterSpan, ...
        'MessageBits',                  prmQAM16Transmitter.MessageBits, ...
        'MessageLength',                prmQAM16Transmitter.MessageLength, ...
        'NumberOfMessage',              prmQAM16Transmitter.NumberOfMessage, ...
        'ScramblerBase',                prmQAM16Transmitter.ScramblerBase, ...
        'ScramblerPolynomial',          prmQAM16Transmitter.ScramblerPolynomial, ...
        'ScramblerInitialConditions',   prmQAM16Transmitter.ScramblerInitialConditions, ...
        'ModulationOrder',              prmQAM16Transmitter.ModulationOrder, ...
        'ShowConstellation',            prmQAM16Transmitter.ShowConstellation);

    % Create and configure the SDRu System object. Set the SerialNum for B2xx
    % radios and IPAddress for X3xx, N2xx, and USRP2 radios. MasterClockRate
    % is not configurable for N2xx and USRP2 radios.
    switch prmQAM16Transmitter.Platform
        %%% PLUTO Radio %%%
        case {'ADALM-PLUTO'}
               % Create and configure the Pluto System object.
               radio = sdrtx('Pluto');
               radio.RadioID               = prmQAM16Transmitter.Address;
               radio.CenterFrequency       = prmQAM16Transmitter.PlutoCenterFrequency;
               radio.BasebandSampleRate    = prmQAM16Transmitter.PlutoFrontEndSampleRate;
               radio.SamplesPerFrame       = prmQAM16Transmitter.PlutoFrameLength;
               radio.Gain                  = prmQAM16Transmitter.PlutoGain;
            %%% USRP Radios %%%
        case {'B200','B210'}
            radio = comm.SDRuTransmitter(...
                'Platform',             prmQAM16Transmitter.Platform, ...
                'SerialNum',            prmQAM16Transmitter.Address, ...
                'MasterClockRate',      prmQAM16Transmitter.MasterClockRate, ...
                'CenterFrequency',      prmQAM16Transmitter.USRPCenterFrequency, ...
                'Gain',                 prmQAM16Transmitter.USRPGain, ...
                'InterpolationFactor',  prmQAM16Transmitter.USRPInterpolationFactor);
        case {'X300','X310'}
            radio = comm.SDRuTransmitter(...
                'Platform',             prmQAM16Transmitter.Platform, ...
                'IPAddress',            prmQAM16Transmitter.Address, ...
                'MasterClockRate',      prmQAM16Transmitter.MasterClockRate, ...
                'CenterFrequency',      prmQAM16Transmitter.USRPCenterFrequency, ...
                'Gain',                 prmQAM16Transmitter.USRPGain, ...
                'InterpolationFactor',  prmQAM16Transmitter.USRPInterpolationFactor);
        case {'N200/N210/USRP2'}
            radio = comm.SDRuTransmitter(...
                'Platform',             prmQAM16Transmitter.Platform, ...
                'IPAddress',            prmQAM16Transmitter.Address, ...
                'CenterFrequency',      prmQAM16Transmitter.USRPCenterFrequency, ...
                'Gain',                 prmQAM16Transmitter.USRPGain, ...
                'InterpolationFactor',  prmQAM16Transmitter.USRPInterpolationFactor);
        case {'N300','N310'}
            radio = comm.SDRuTransmitter(...
                'Platform',             prmQAM16Transmitter.Platform, ...
                'IPAddress',            prmQAM16Transmitter.Address, ...
                'MasterClockRate',      prmQAM16Transmitter.MasterClockRate, ...
                'CenterFrequency',      prmQAM16Transmitter.USRPCenterFrequency, ...
                'Gain',                 prmQAM16Transmitter.USRPGain, ...
                'InterpolationFactor',  prmQAM16Transmitter.USRPInterpolationFactor);
        case {'N320/N321'}
            radio = comm.SDRuTransmitter(...
                'Platform',             prmQAM16Transmitter.Platform, ...
                'IPAddress',            prmQAM16Transmitter.Address, ...
                'MasterClockRate',      prmQAM16Transmitter.MasterClockRate, ...
                'CenterFrequency',      prmQAM16Transmitter.USRPCenterFrequency, ...
                'Gain',                 prmQAM16Transmitter.USRPGain, ...
                'InterpolationFactor',  prmQAM16Transmitter.USRPInterpolationFactor);
    end
end

cleanupTx = onCleanup(@()release(qam16Tx));
cleanupRadio = onCleanup(@()release(radio));

currentTime = 0;
underrun = 0;

%Transmission Process
while currentTime < prmQAM16Transmitter.StopTime
    % Bit generation, modulation and transmission filtering
    data = qam16Tx();

    % Data transmission
    tunderrun = radio(data);
    underrun = underrun + tunderrun;

    % Update simulation time
    currentTime=currentTime+prmQAM16Transmitter.SDRFrameTime;
end