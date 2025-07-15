classdef QAM16BitsGenerator < matlab.System
    %#codegen
    % Generates the bits for each frame for 16-QAM
    
    %   Modified from QPSKBitsGenerator for 16-QAM
    
    properties (Nontunable)
        ScramblerBase = 2;
        ScramblerPolynomial = [1 1 1 0 1];
        ScramblerInitialConditions = [0 0 0 0];
        NumberOfMessage = 10;
        MessageLength = 16;
        MessageBits = [];
        ModulationOrder = 16; % 16-QAM
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
        function obj = QAM16BitsGenerator(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj, ~)
            % Generate unipolar Barker Code and duplicate it as header
            % For 16-QAM, we need 4 bits per symbol, so we need to adjust header accordingly
            ubc = ((obj.pBarkerCode + 1) / 2)';
            
            % Convert to 4-bit representation for 16-QAM
            % Each Barker code bit becomes 4 bits (to match 16-QAM symbol requirement)
            header_4bit = [];
            for i = 1:length(ubc)
                if ubc(i) == 1
                    header_4bit = [header_4bit; [1; 1; 1; 1]]; % Map 1 to [1,1,1,1]
                else
                    header_4bit = [header_4bit; [0; 0; 0; 0]]; % Map 0 to [0,0,0,0]
                end
            end
            
            % Duplicate header (same as original QPSK version)
            temp = (repmat(header_4bit,1,2))';
            obj.pHeader = temp(:);
            
            % Initialize scrambler system object
            obj.pScrambler = comm.Scrambler( ...
                obj.ScramblerBase, ...
                obj.ScramblerPolynomial, ...
                obj.ScramblerInitialConditions);
            
            % Initialize signal source
            obj.pSigSrc = dsp.SignalSource(obj.MessageBits, ...
                'SamplesPerFrame', obj.MessageLength * 7 * obj.NumberOfMessage, ...
                'SignalEndAction', 'Cyclic repetition');
            
        end
        
        function [y, msgBin] = stepImpl(obj)
            
            % Generate message binaries from signal source.
            msgBin = obj.pSigSrc();
            
            % Scramble the data
            scrambledMsg = obj.pScrambler(msgBin);
            
            % Append the scrambled bit sequence to the header
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