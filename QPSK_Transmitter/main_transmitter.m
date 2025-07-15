

platform = 'B210';
address = '30FB56D'; 
sampleRate         = 1000000;  % Sample rate of transmitted signal
SDRGain            = 50;  % Set radio gain
SDRCenterFrequency = 915000000;  % Set radio center frequency
SDRStopTime        = 50;  % Radio transmit time in seconds

prmQPSKTransmitter = sdrQPSKTransmitterInit(platform, address, sampleRate, SDRCenterFrequency, ...
    SDRGain, SDRStopTime);

underruns = runSDRQPSKTransmitter(prmQPSKTransmitter);
fprintf('Total number of underruns = %d.\n', underruns);

