%% Example Receiver Function with Constellation Diagram
% Bu fonksiyonu mevcut receiver kodunuza entegre etmeniz gerekecek
function [BER, overflow, output] = runSDRQPSKReceiverWithConstellation(prmQPSKReceiver, previewReceivedData, printReceivedData)
    % Bu fonksiyon mevcut runSDRQPSKReceiver fonksiyonunuzun modifiye edilmiş versiyonu olmalı
    
    % Mevcut receiver kodunuz burada çalışacak...
    % ...
    
    % Demodulated symbols'ları aldıktan sonra (receiver'da bir yerde):
    % Örnek kullanım:
    if prmQPSKReceiver.showConstellation
        % receivedSymbols değişkeni receiver'da demodulated symbols'ları içermeli
        % Bu değişken adı sizin kodunuza göre farklı olabilir
        
        % Örnek: rastgele QPSK sembolleri (gerçek kodunuzda bu receiver'dan gelecek)
        numSymbols = 1000;
        noise_power = 0.1;
        ideal_symbols = [1+1j, -1+1j, -1-1j, 1-1j] * exp(1j*pi/4);
        symbol_indices = randi(4, numSymbols, 1);
        receivedSymbols = ideal_symbols(symbol_indices) + ...
                         noise_power * (randn(numSymbols,1) + 1j*randn(numSymbols,1));
        
        % Constellation diagram'ı göster
        showConstellationDiagram(receivedSymbols, 'Received QPSK Constellation');
    end
    
    % Mevcut return değerleriniz
    BER = [0.05, 50, 1000]; % Örnek değerler
    overflow = 0;
    output = [];
end
