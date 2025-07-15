function connectedRadios = helperFindRadios(varargin)
%   Copyright 2023 The MathWorks, Inc.

narginchk(0, 1);

isAvailableRadios = 1;

if  nargin > 0
    findMode = varargin{1};
    findMode = validatestring(findMode, ["allRadios", "availableRadios"]);
    if strncmpi(findMode, "allRadios", 2)
        isAvailableRadios = 0;
    end
end

if isAvailableRadios
    [~, connectedRadios] = evalc('showAvailableRadios()');
else
    [~, connectedRadios] = evalc('showAllRadios()');
end
disp(connectedRadios);
end

function connectedRadios = showAvailableRadios()
Platform = {};
Address = {};

warning('off');
cleanup = onCleanup(@()warning('on'));

plutoRadios = findPlutoRadio;
if ~isempty(plutoRadios)
    numPlutoRadios = length(plutoRadios);
    plutoName = {}; %#ok<NASGU>
    rx = [];
    for ii = 1:numPlutoRadios
        rx = sdrrx('Pluto', RadioID=plutoRadios(ii).RadioID);
        metaData = info(rx);
        isRadioAvailable = ((length(fields(metaData)) > 1) && ...
            strcmpi(metaData.Status, 'Full information'));
        if isRadioAvailable
            Platform{end + 1} = 'ADALM-PLUTO'; %#ok<*AGROW>
            Address{end + 1} = rx.RadioID;
        end
        release(rx);
    end
    delete(rx);
end

usrpRadios = findsdru;
if ~isempty(usrpRadios)
    usrpActiveDevices = {usrpRadios.Status};
    usrpActiveDevicesIdx = strncmpi(usrpActiveDevices, 's', 1);
    usrpActiveDevices = usrpRadios(usrpActiveDevicesIdx);

    usrpActivePlatforms = {usrpActiveDevices.Platform};
    usrpActiveBPlatformsIdx = strncmpi(usrpActivePlatforms, 'b', 1);

    Platform = [Platform, usrpActivePlatforms(usrpActiveBPlatformsIdx), usrpActivePlatforms(~usrpActiveBPlatformsIdx)];
    usrpBAddress  = {usrpActiveDevices(usrpActiveBPlatformsIdx).SerialNum};
    usrpNXAddress = {usrpActiveDevices(~usrpActiveBPlatformsIdx).IPAddress};
    Address = [Address usrpBAddress(:)', usrpNXAddress(:)'];
end

Platform = string(Platform(:));
Address = string(Address(:));
connectedRadios = table(Platform, Address);
fprintf('\n');
end

function connectedRadios = showAllRadios()
Platform = {};
Address = {};
Status = [];

warning('off');
cleanup = onCleanup(@()warning('on'));

plutoRadios = findPlutoRadio;
if ~isempty(plutoRadios)
    numPlutoRadios = length(plutoRadios);
    plutoName = {}; %#ok<NASGU>
    rx = [];
    for ii = 1:numPlutoRadios
        rx = sdrrx('Pluto', RadioID=plutoRadios(ii).RadioID);
        metaData = info(rx);
        isRadioAvailable = ((length(fields(metaData)) > 1) && ...
            strcmpi(metaData.Status, 'Full information'));
        Platform{end + 1} = 'ADALM-PLUTO'; %#ok<*AGROW>
        Address{end + 1} = rx.RadioID;
        if isRadioAvailable
            Status = [Status; "Avaialable"];
        else
            Status = [Status; "Busy"];
        end
        release(rx);
    end
    delete(rx);
end

usrpRadios = findsdru;
if ~isempty(usrpRadios)
    usrpPlatforms = {usrpRadios.Platform};
    usrpBPlatformsIdx = strncmpi(usrpPlatforms, 'b', 1);
    usrpNonBPlatformsIdx = ~usrpBPlatformsIdx;

    usrpBPlatforms = usrpPlatforms(usrpBPlatformsIdx);
    usrpNXPlatforms = usrpPlatforms(usrpNonBPlatformsIdx);

    usrpBAddress  = {usrpRadios(usrpBPlatformsIdx).SerialNum};
    usrpNXAddress = {usrpRadios(usrpNonBPlatformsIdx).IPAddress};

    usrpBStatus = string({usrpRadios(usrpBPlatformsIdx).Status});
    usrpNXStatus = string({usrpRadios(usrpNonBPlatformsIdx).Status});

    usrpActiveBDevicesIdx = strncmpi(usrpBStatus, 's', 1);
    usrpBStatus(usrpActiveBDevicesIdx) = "Available";
    usrpBStatus(~usrpActiveBDevicesIdx) = "Busy";

    usrpActiveNXDevicesIdx = strncmpi(usrpNXStatus, 's', 1);
    usrpNXStatus(usrpActiveNXDevicesIdx) = "Available";
    usrpNXStatus(~usrpActiveNXDevicesIdx) = "Busy";

    Platform = [Platform, usrpBPlatforms, usrpNXPlatforms];
    Address = [Address usrpBAddress(:)', usrpNXAddress(:)'];
    Status = [Status; usrpBStatus(:); usrpNXStatus(:)];    
end

Platform = string(Platform(:));
Address = string(Address(:));
connectedRadios = table(Platform, Address, Status);
fprintf('\n');
end







