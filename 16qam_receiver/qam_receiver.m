platform = 'B210';
address = '30FB55F';

sampleRate          = 1000000;
isHDLCompatible     = false;

% SDR Parameters
SDRGain             = 35;
SDRCenterFrequency  = 915000000;
SDRStopTime         = 10;

% Display configuration
previewReceivedData = true;
printReceivedData   = false;
showConstellation   = true;

% Receiver parameter structure
% sdrQPSKReceiverInit fonksiyonu çağrılıyor
prmQPSKReceiver = sdrQPSKReceiverInit(platform, address, sampleRate, SDRCenterFrequency, ...
    SDRGain, SDRStopTime, isHDLCompatible, 'ShowConstellation', showConstellation);

% runSDRQPSKReceiver fonksiyonu çağrılıyor
[BER, overflow, output] = runSDRQPSKReceiver(prmQPSKReceiver, previewReceivedData, printReceivedData); 

fprintf('Error rate is = %f.\n', BER(1));
fprintf('Number of detected errors = %d.\n', BER(2));
fprintf('Total number of compared samples = %d.\n', BER(3));
fprintf('Total number of overflows = %d.\n', overflow);