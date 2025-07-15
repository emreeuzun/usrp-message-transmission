platform = 'B210';
address = '30FB55F';

sampleRate          = 1000000;
isHDLCompatible     = false;  % disable to run 'FFT-Based' coarse frequency compensation instead of 'Correlation-Based' for improved performance in MATLAB version.

% SDR Parameters
SDRGain             = 35;
SDRCenterFrequency  = 915000000;
SDRStopTime         = 35;

% Display configuration
previewReceivedData = true;   % enable to preview the received data 
printReceivedData   = false;  % enable to print the received data
showConstellation   = true;   % enable to show constellation diagram

% Receiver parameter structure
prmQPSKReceiver = sdrQPSKReceiverInit(platform, address, sampleRate, SDRCenterFrequency, ...
    SDRGain, SDRStopTime, isHDLCompatible, 'ShowConstellation', showConstellation);

[BER, overflow, output] = runSDRQPSKReceiver(prmQPSKReceiver, previewReceivedData, printReceivedData); 

fprintf('Error rate is = %f.\n', BER(1));
fprintf('Number of detected errors = %d.\n', BER(2));
fprintf('Total number of compared samples = %d.\n', BER(3));
fprintf('Total number of overflows = %d.\n', overflow);