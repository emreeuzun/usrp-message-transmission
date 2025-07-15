classdef (StrictDefaults)QPSKTransmitter < matlab.System
%#codegen
% Generates the QPSK signal to be transmitted

%   Copyright 2012-2017 The MathWorks, Inc.

properties (Nontunable)
    UpsamplingFactor = 2;
    ScramblerBase = 2;
    ScramblerPolynomial = [1 1 1 0 1];
    ScramblerInitialConditions = [0 0 0 0];
    RolloffFactor = 0.5
    RaisedCosineFilterSpan = 10
    NumberOfMessage = 10
    MessageLength = 16
    MessageBits = []
end

properties (Access=private)
    pBitGenerator
    pQPSKModulator
    pTransmitterFilter
    pConstDiagram % Takımyıldız diyagramı nesnesi
end


methods
    function obj = QPSKTransmitter(varargin)
        setProperties(obj,nargin,varargin{:});
    end
end

methods (Access=protected)
    function setupImpl(obj)
        obj.pBitGenerator = QPSKBitsGenerator( ...
            'NumberOfMessage',              obj.NumberOfMessage, ...
            'MessageLength',                obj.MessageLength, ...
            'MessageBits',                  obj.MessageBits, ...
            'ScramblerBase',                obj.ScramblerBase, ...
            'ScramblerPolynomial',          obj.ScramblerPolynomial, ...
            'ScramblerInitialConditions',   obj.ScramblerInitialConditions);

        obj.pQPSKModulator  = comm.QPSKModulator( ...
            'BitInput',                     true, ...
            'PhaseOffset',                  pi/4, ...
            'OutputDataType',               'double');

        obj.pTransmitterFilter = comm.RaisedCosineTransmitFilter( ...
            'RolloffFactor',                obj.RolloffFactor, ...
            'FilterSpanInSymbols',          obj.RaisedCosineFilterSpan, ...
            'OutputSamplesPerSymbol',       obj.UpsamplingFactor);

        % Takımyıldız diyagramını oluştur ve yapılandır
        obj.pConstDiagram = comm.ConstellationDiagram( ...
            'Title', 'Verici Takımyıldız Diyagramı', ...
            'ShowReferenceConstellation', true, ...
            'ReferenceConstellation', [1+1i, -1+1i, -1-1i, 1-1i]/sqrt(2), ...
            'SamplesPerSymbol', 1);
    end

    function transmittedSignal = stepImpl(obj)
        [transmittedBin, ~] = obj.pBitGenerator();                 % Gönderilecek veriyi üret
        modulatedData = obj.pQPSKModulator(transmittedBin);        % Bitleri QPSK sembollerine modüle et

        % Modüle edilmiş veriyi takımyıldız diyagramında göster
        obj.pConstDiagram(modulatedData);

        transmittedSignal = obj.pTransmitterFilter(modulatedData); % Kök Yükseltilmiş Kosinüs Gönderici Filtresi uygula
    end

    function resetImpl(obj)
        reset(obj.pBitGenerator);
        reset(obj.pQPSKModulator);
        reset(obj.pTransmitterFilter);
        reset(obj.pConstDiagram); % Diyagramı sıfırla
    end

    function releaseImpl(obj)
        release(obj.pBitGenerator);
        release(obj.pQPSKModulator);
        release(obj.pTransmitterFilter);
        release(obj.pConstDiagram); % Diyagramı serbest bırak
    end

    function N = getNumInputsImpl(~)
        N = 0;
    end
end
end