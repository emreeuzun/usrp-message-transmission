classdef QPSKBitsGenerator < matlab.System
    %#codegen
    % Generates the bits for each frame
    
    %   Copyright 2012-2017 The MathWorks, Inc.
    
    properties (Nontunable)
        ScramblerBase = 2;
        ScramblerPolynomial = [1 1 1 0 1];
        ScramblerInitialConditions = [0 0 0 0];
        NumberOfMessage = 10;
        MessageLength = 16;
        MessageBits = [];
    end
    
    properties (Access=private)
        pHeader
        pScrambler
        pSigSrc
    end
    
    properties (Access=private, Nontunable)
        pBarkerCode = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1]; % Bipolar Barker Code
    end
    
    methods
        function obj = QPSKBitsGenerator(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj, ~)
            % Unipolar Barker Kodunu oluştur ve başlık olarak çoğalt
            ubc = ((obj.pBarkerCode + 1) / 2)';
            temp = (repmat(ubc,1,2))';
            obj.pHeader = temp(:);
            
            % Scrambler sistem nesnesini başlat
            obj.pScrambler = comm.Scrambler( ...
                obj.ScramblerBase, ...
                obj.ScramblerPolynomial, ...
                obj.ScramblerInitialConditions);
            
            % Sinyal kaynağını başlat
            obj.pSigSrc = dsp.SignalSource(obj.MessageBits, ...
                'SamplesPerFrame', obj.MessageLength * 7 * obj.NumberOfMessage, ...
                'SignalEndAction', 'Cyclic repetition');
        end
        
        function [y, msgBin] = stepImpl(obj)
            % Sinyal kaynağından mesaj bitlerini üret
            msgBin = obj.pSigSrc();
            
            % Veriyi karıştır (scramble)
            scrambledMsg = obj.pScrambler(msgBin);
            
            % Karıştırılmış bit dizisini başlığa ekle
            y = [obj.pHeader ; scrambledMsg];
        end
        
        function resetImpl(obj)
            reset(obj.pScrambler);
            reset(obj.pSigSrc);
        end
        
        function releaseImpl(obj)
            release(obj.pScrambler);
            release(obj.pSigSrc);
        end
        
        function N = getNumInputsImpl(~)
            N = 0;
        end
        
        function N = getNumOutputsImpl(~)
            N = 2;
        end
    end
end