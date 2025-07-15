platform = 'B210';
address = '30FB56D'; 
sampleRate         = 1000000;  % Sample rate of transmitted signal
SDRGain            = 50;  % Set radio gain
SDRCenterFrequency = 915000000;  % Set radio center frequency
SDRStopTime        = 20;  % Radio transmit time in seconds

% Display configuration
showConstellation   = true;   % enable to show constellation diagram

prmQAM16Transmitter = sdrQAM16TransmitterInit(platform, address, sampleRate, SDRCenterFrequency, ...
    SDRGain, SDRStopTime, 'ShowConstellation', showConstellation);

underruns = runSDRQAM16Transmitter(prmQAM16Transmitter);
fprintf('Total number of underruns = %d.\n', underruns);