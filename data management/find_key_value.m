function meta = find_key_value(path)
%FIND_KEY_VALUE
% Extrait les paramètres utiles d'un XML Prairie View.

meta = struct();

meta.RecordingTime         = '';
meta.ActiveMode            = '';
meta.BitDepth              = NaN;

meta.SamplingRate          = NaN;
meta.FramePeriod           = NaN;
meta.SamplingRatePlane     = NaN;
meta.InterplaneDelay_s     = NaN;

meta.PixelsPerLine         = NaN;
meta.LinesPerFrame         = NaN;
meta.ImageSize             = '';
meta.DwellTime_us          = NaN;
meta.ScanLinePeriod_s      = NaN;
meta.SamplesPerPixel       = NaN;

meta.OpticalZoom           = NaN;
meta.ObjectiveLens         = '';
meta.ObjectiveLensMag      = NaN;
meta.ObjectiveLensNA       = NaN;

meta.PixelSizeX_um         = NaN;
meta.PixelSizeY_um         = NaN;
meta.PixelSize_um          = NaN;

meta.PositionX_um          = NaN;
meta.PositionY_um          = NaN;
meta.PositionZ             = '';

meta.NumPlanes             = 1;
meta.ZStep_um              = NaN;
meta.ZMin_um               = NaN;
meta.ZMax_um               = NaN;

meta.LaserWavelength_nm    = NaN;
meta.LaserPower_Pockels    = NaN;
meta.LaserPowerByPlane_Pockels = '';

meta.PMTGain_Red           = NaN;
meta.PMTGain_Green         = NaN;
meta.PMTGain_Blue          = NaN;

meta.TimeMinutes           = NaN;
meta.NumFrames             = NaN;
meta.ChannelNames          = '';
meta.NumChannels           = NaN;
meta.BidirectionalZ        = '';

str2num_local = @(s) str2double(strrep(char(s), ',', '.'));

try
    xmlDoc = xmlread(path);
    rootNode = xmlDoc.getDocumentElement();

    if ~isempty(rootNode) && rootNode.hasAttribute('date')

        date_str = char(rootNode.getAttribute('date'));
        split_date = strsplit(date_str);
    
        if numel(split_date) > 1
            meta.RecordingTime = split_date{2};
    
            if numel(split_date) > 2
                meta.RecordingTime = [meta.RecordingTime ' ' split_date{3}];
            end
        end
    end

    pvNodes = xmlDoc.getElementsByTagName('PVStateValue');

    for i = 0:pvNodes.getLength-1

        currentNode = pvNodes.item(i);
        key = char(currentNode.getAttribute('key'));

        switch key

            case 'activeMode'
                meta.ActiveMode = char(currentNode.getAttribute('value'));

            case 'bitDepth'
                meta.BitDepth = str2num_local(currentNode.getAttribute('value'));

            case 'framerate'
                meta.SamplingRate = str2num_local(currentNode.getAttribute('value'));

            case 'framePeriod'
                meta.FramePeriod = str2num_local(currentNode.getAttribute('value'));
                if isnan(meta.SamplingRate) && meta.FramePeriod > 0
                    meta.SamplingRate = 1 / meta.FramePeriod;
                end

            case 'pixelsPerLine'
                meta.PixelsPerLine = str2num_local(currentNode.getAttribute('value'));

            case 'linesPerFrame'
                meta.LinesPerFrame = str2num_local(currentNode.getAttribute('value'));

            case 'dwellTime'
                meta.DwellTime_us = str2num_local(currentNode.getAttribute('value'));

            case 'scanLinePeriod'
                meta.ScanLinePeriod_s = str2num_local(currentNode.getAttribute('value'));

            case 'samplesPerPixel'
                meta.SamplesPerPixel = str2num_local(currentNode.getAttribute('value'));

            case 'opticalZoom'
                meta.OpticalZoom = str2num_local(currentNode.getAttribute('value'));

            case 'objectiveLens'
                meta.ObjectiveLens = char(currentNode.getAttribute('value'));

            case 'objectiveLensMag'
                meta.ObjectiveLensMag = str2num_local(currentNode.getAttribute('value'));

            case 'objectiveLensNA'
                meta.ObjectiveLensNA = str2num_local(currentNode.getAttribute('value'));

            case 'micronsPerPixel'
                [meta.PixelSizeX_um, meta.PixelSizeY_um] = get_indexed_xy(currentNode);

                if ~isnan(meta.PixelSizeX_um) && ~isnan(meta.PixelSizeY_um)
                    meta.PixelSize_um = mean([meta.PixelSizeX_um, meta.PixelSizeY_um]);
                elseif ~isnan(meta.PixelSizeX_um)
                    meta.PixelSize_um = meta.PixelSizeX_um;
                elseif ~isnan(meta.PixelSizeY_um)
                    meta.PixelSize_um = meta.PixelSizeY_um;
                end

            case 'laserWavelength'
                meta.LaserWavelength_nm = get_indexed_value(currentNode, '0');

            case 'laserPower'
                % On garde seulement la première valeur globale du XML.
                % Les valeurs par plan seront lues séparément dans les Frames.
                if isnan(meta.LaserPower_Pockels)
                    meta.LaserPower_Pockels = get_indexed_value(currentNode, '0');
                end

            case 'pmtGain'
                meta.PMTGain_Red   = get_indexed_value_by_description(currentNode, 'Red');
                meta.PMTGain_Green = get_indexed_value_by_description(currentNode, 'Green');
                meta.PMTGain_Blue  = get_indexed_value_by_description(currentNode, 'Blue');

            case 'positionCurrent'
                [meta.PositionX_um, meta.PositionY_um, z_str] = get_position_xyz(currentNode);
                if ~isempty(z_str)
                    meta.PositionZ = z_str;
                end
        end
    end

    if ~isnan(meta.PixelsPerLine) && ~isnan(meta.LinesPerFrame)
        meta.ImageSize = sprintf('%d x %d', ...
            meta.PixelsPerLine, meta.LinesPerFrame);
    end

    frameNodes = xmlDoc.getElementsByTagName('Frame');
    meta.NumFrames = frameNodes.getLength;

    [meta.TimeMinutes, abs_times] = get_recording_duration(frameNodes);
    [meta.ChannelNames, meta.NumChannels] = get_channel_names(frameNodes);
    [meta.NumPlanes, z_positions, meta.BidirectionalZ] = get_zseries_info(xmlDoc);

    if ~isempty(z_positions)
        meta.PositionZ = vector_to_string(z_positions);
        meta.ZMin_um = min(z_positions);
        meta.ZMax_um = max(z_positions);

        if numel(z_positions) > 1
            dz = diff(sort(z_positions));
            dz = dz(abs(dz) > 1e-9);

            if ~isempty(dz)
                meta.ZStep_um = median(abs(dz));
            end
        end
    end

    meta.LaserPowerByPlane_Pockels = ...
        extract_laser_power_by_plane(xmlDoc, meta.LaserPower_Pockels);

    if meta.NumPlanes <= 1
        meta.SamplingRatePlane = meta.SamplingRate;
        meta.InterplaneDelay_s = 0;
    else
        if numel(abs_times) > meta.NumPlanes
            dt_same_plane = abs_times(1+meta.NumPlanes:end) - ...
                            abs_times(1:end-meta.NumPlanes);
            dt_same_plane = dt_same_plane(dt_same_plane > 0);

            if ~isempty(dt_same_plane)
                meta.SamplingRatePlane = 1 / median(dt_same_plane);
            end
        end

        if numel(abs_times) >= 2 && ~isnan(meta.SamplingRate)
            dt_consecutive = diff(abs_times);
            dt_consecutive = dt_consecutive(dt_consecutive > 0);

            if ~isempty(dt_consecutive)
                meta.InterplaneDelay_s = median(dt_consecutive) - ...
                    (1 / meta.SamplingRate);

                if meta.InterplaneDelay_s < 0
                    meta.InterplaneDelay_s = 0;
                end
            end
        end
    end

catch ME
    fprintf('Erreur lors de la lecture du fichier XML : %s\n', ME.message);
end

end

%% ========================================================================
function [x, y] = get_indexed_xy(node)

x = NaN;
y = NaN;

idxNodes = node.getElementsByTagName('IndexedValue');

for j = 0:idxNodes.getLength-1

    idxNode = idxNodes.item(j);
    axis_name = char(idxNode.getAttribute('index'));
    value = str2double(char(idxNode.getAttribute('value')));

    if strcmp(axis_name, 'XAxis')
        x = value;
    elseif strcmp(axis_name, 'YAxis')
        y = value;
    end
end

end

%% ========================================================================
function value = get_indexed_value(node, wanted_index)

value = NaN;

idxNodes = node.getElementsByTagName('IndexedValue');

for j = 0:idxNodes.getLength-1

    idxNode = idxNodes.item(j);

    if strcmp(char(idxNode.getAttribute('index')), wanted_index)
        value = str2double(char(idxNode.getAttribute('value')));
        return;
    end
end

end

%% ========================================================================
function value = get_indexed_value_by_description(node, wanted_description)

value = NaN;

idxNodes = node.getElementsByTagName('IndexedValue');

for j = 0:idxNodes.getLength-1

    idxNode = idxNodes.item(j);

    if idxNode.hasAttribute('description')
        descr = char(idxNode.getAttribute('description'));

        if strcmpi(descr, wanted_description)
            value = str2double(char(idxNode.getAttribute('value')));
            return;
        end
    end
end

end

%% ========================================================================
function [x, y, z_string] = get_position_xyz(node)

x = NaN;
y = NaN;
z_string = '';

subNodes = node.getElementsByTagName('SubindexedValues');

z_focus = NaN;
etl_raw = NaN;

for j = 0:subNodes.getLength-1

    subNode = subNodes.item(j);
    axis_name = char(subNode.getAttribute('index'));
    valNodes = subNode.getElementsByTagName('SubindexedValue');

    for v = 0:valNodes.getLength-1

        valNode = valNodes.item(v);
        val = str2double(char(valNode.getAttribute('value')));

        if strcmp(axis_name, 'XAxis')
            x = val;

        elseif strcmp(axis_name, 'YAxis')
            y = val;

        elseif strcmp(axis_name, 'ZAxis')

            descr = '';
            if valNode.hasAttribute('description')
                descr = char(valNode.getAttribute('description'));
            end

            subidx = '';
            if valNode.hasAttribute('subindex')
                subidx = char(valNode.getAttribute('subindex'));
            end

            if contains(descr, 'Z Focus') || strcmp(subidx, '0')
                z_focus = val;
            elseif contains(descr, 'Optotune') || strcmp(subidx, '1')
                etl_raw = val;
            end
        end
    end
end

if ~isnan(z_focus)

    if isnan(etl_raw)
        etl_raw = 0;
    end

    if abs(etl_raw) < 1e-6
        etl_raw = 0;
    end

    z_string = sprintf('%.4f', z_focus + etl_raw / 1000);
end

end

%% ========================================================================
function [time_minutes, abs_times] = get_recording_duration(frameNodes)

time_minutes = NaN;
nFrames = frameNodes.getLength;
abs_times = nan(1, nFrames);

for f = 0:nFrames-1

    frameNode = frameNodes.item(f);

    if frameNode.hasAttribute('absoluteTime')
        abs_times(f+1) = str2double(char(frameNode.getAttribute('absoluteTime')));
    end
end

valid_t = abs_times(isfinite(abs_times));

if numel(valid_t) >= 2
    time_minutes = (max(valid_t) - min(valid_t)) / 60;
end

end

%% ========================================================================
function [channel_names, n_channels] = get_channel_names(frameNodes)

names = {};

for f = 0:frameNodes.getLength-1

    frameNode = frameNodes.item(f);
    fileNodes = frameNode.getElementsByTagName('File');

    for j = 0:fileNodes.getLength-1

        fileNode = fileNodes.item(j);

        if fileNode.hasAttribute('channelName')
            names{end+1} = char(fileNode.getAttribute('channelName')); %#ok<AGROW>
        elseif fileNode.hasAttribute('channel')
            names{end+1} = ['Ch' char(fileNode.getAttribute('channel'))]; %#ok<AGROW>
        end
    end
end

names = unique(names, 'stable');
n_channels = numel(names);

if isempty(names)
    channel_names = '';
else
    channel_names = strjoin(names, ', ');
end

end

%% ========================================================================
function [n_planes, z_positions, bidirectionalZ] = get_zseries_info(xmlDoc)

n_planes = 1;
z_positions = [];
bidirectionalZ = '';

% Position Z globale, utile quand le plan du milieu n'est pas répété
% dans les Frames
global_z = NaN;

pvNodesGlobal = xmlDoc.getElementsByTagName('PVStateValue');

for i = 0:pvNodesGlobal.getLength-1

    pvNode = pvNodesGlobal.item(i);

    if strcmp(char(pvNode.getAttribute('key')), 'positionCurrent')
        [~, ~, z_str] = get_position_xyz(pvNode);

        if ~isempty(z_str)
            global_z = str2double(z_str);
            break;
        end
    end
end

seqNodes = xmlDoc.getElementsByTagName('Sequence');

for s = 0:seqNodes.getLength-1

    seqNode = seqNodes.item(s);

    if seqNode.hasAttribute('bidirectionalZ')
        bidirectionalZ = char(seqNode.getAttribute('bidirectionalZ'));
    end

    if ~seqNode.hasAttribute('type')
        continue;
    end

    seqType = char(seqNode.getAttribute('type'));

    if ~contains(seqType, 'ZSeries')
        continue;
    end

    frameNodesSeq = seqNode.getElementsByTagName('Frame');
    n_planes = frameNodesSeq.getLength;

    z_positions = nan(1, n_planes);

    for f = 0:n_planes-1

        frameNode = frameNodesSeq.item(f);

        if frameNode.hasAttribute('index')
            plane_idx = str2double(char(frameNode.getAttribute('index')));
        else
            plane_idx = f + 1;
        end

        if isnan(plane_idx) || plane_idx < 1 || plane_idx > n_planes
            plane_idx = f + 1;
        end

        pvNodes = frameNode.getElementsByTagName('PVStateValue');

        for p = 0:pvNodes.getLength-1

            pvNode = pvNodes.item(p);

            if ~strcmp(char(pvNode.getAttribute('key')), 'positionCurrent')
                continue;
            end

            [~, ~, z_str] = get_position_xyz(pvNode);

            if ~isempty(z_str)
                z_positions(plane_idx) = str2double(z_str);
            end
        end
    end

    % Si un ou plusieurs plans n'ont pas de position Z dans leur Frame,
    % on reconstruit à partir de la position globale.
    if any(isnan(z_positions)) && ~isnan(global_z)

        missing_idx = find(isnan(z_positions));

        if n_planes == 1
            z_positions(1) = global_z;

        elseif n_planes == 3
            % Cas Prairie classique :
            % plan 1 = global - dz
            % plan 2 = global
            % plan 3 = global + dz
            known_idx = find(~isnan(z_positions));

            if numel(known_idx) >= 1
                dz_candidates = abs(z_positions(known_idx) - global_z);
                dz_candidates = dz_candidates(dz_candidates > 1e-9);

                if ~isempty(dz_candidates)
                    dz = median(dz_candidates);
                else
                    dz = NaN;
                end

                if ~isnan(dz)
                    z_positions = [global_z - dz, global_z, global_z + dz];
                else
                    z_positions(missing_idx) = global_z;
                end
            else
                z_positions(missing_idx) = global_z;
            end

        else
            % Fallback général : on remplit les absents avec global_z
            z_positions(missing_idx) = global_z;
        end
    end

    z_positions = z_positions(isfinite(z_positions));
    break;
end

end
%% ========================================================================

function str = extract_laser_power_by_plane(xmlDoc, default_power)

powers = [];

seqNodes = xmlDoc.getElementsByTagName('Sequence');

for s = 0:seqNodes.getLength-1

    seqNode = seqNodes.item(s);

    if ~seqNode.hasAttribute('type')
        continue;
    end

    seqType = char(seqNode.getAttribute('type'));

    if ~contains(seqType, 'ZSeries')
        continue;
    end

    frameNodes = seqNode.getElementsByTagName('Frame');
    nPlanes = frameNodes.getLength;

    powers = repmat(default_power, 1, nPlanes);

    for f = 0:nPlanes-1

        frameNode = frameNodes.item(f);

        if frameNode.hasAttribute('index')
            plane_idx = str2double(char(frameNode.getAttribute('index')));
        else
            plane_idx = f + 1;
        end

        if isnan(plane_idx) || plane_idx < 1 || plane_idx > nPlanes
            plane_idx = f + 1;
        end

        pvNodes = frameNode.getElementsByTagName('PVStateValue');

        for p = 0:pvNodes.getLength-1

            pvNode = pvNodes.item(p);

            if strcmp(char(pvNode.getAttribute('key')), 'laserPower')

                v = get_indexed_value(pvNode, '0');

                if ~isnan(v)
                    powers(plane_idx) = v;
                end
            end
        end
    end

    break;
end

str = vector_to_string(powers);

end
%% ========================================================================
function str = vector_to_string(v)

if isempty(v)
    str = '';
    return;
end

v = v(:)';

parts = cell(1, numel(v));

for i = 1:numel(v)
    if isnan(v(i))
        parts{i} = 'NaN';
    else
        parts{i} = sprintf('%.4f', v(i));
    end
end

str = strjoin(parts, ' ');

end