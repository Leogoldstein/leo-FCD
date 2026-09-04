function meta = find_zseries_metadata(xml_file)
%FIND_ZSERIES_METADATA
%
% Extrait les metadata pertinentes d'une acquisition Prairie View ZSeries.
%
% Une Frame correspond à une coupe acquise à une position Z.
%
% Champs retournés :
%
%   Date
%   RecordingTime
%
%   NumSlices
%
%   ZStart_um
%   ZEnd_um
%   ZStep_um
%   ZSpan_um
%   ZDirection
%   ZPositions
%
%   PositionX_um
%   PositionY_um
%
%   PixelsPerLine
%   LinesPerFrame
%   ImageSize
%
%   PixelSizeX_um
%   PixelSizeY_um
%   PixelSize_um
%
%   OpticalZoom
%   ObjectiveLens
%
%   LaserWavelength_nm
%   LaserPowerByPlane_Pockels
%   LaserPowerMin_Pockels
%   LaserPowerMax_Pockels
%   LaserPowerGradient_Pockels_per_um
%
%   PMTGain_Electroporated


    % ==============================================================
    % Initialisation
    % ==============================================================

    meta = struct();

    meta.Date = '';
    meta.RecordingTime = '';

    meta.NumSlices = NaN;

    meta.ZStart_um = NaN;
    meta.ZEnd_um = NaN;
    meta.ZStep_um = NaN;
    meta.ZSpan_um = NaN;

    meta.ZDirection = '';
    meta.ZPositions = '';

    meta.PositionX_um = NaN;
    meta.PositionY_um = NaN;

    meta.PixelsPerLine = NaN;
    meta.LinesPerFrame = NaN;
    meta.ImageSize = '';

    meta.PixelSizeX_um = NaN;
    meta.PixelSizeY_um = NaN;
    meta.PixelSize_um = NaN;

    meta.OpticalZoom = NaN;
    meta.ObjectiveLens = '';

    meta.LaserWavelength_nm = NaN;

    meta.LaserPowerByPlane_Pockels = '';
    meta.LaserPowerMin_Pockels = NaN;
    meta.LaserPowerMax_Pockels = NaN;
    meta.LaserPowerGradient_Pockels_per_um = NaN;

    meta.PMTGain_Electroporated = NaN;


    % ==============================================================
    % XML absent
    % ==============================================================

    if isempty(xml_file) || ...
            exist(xml_file, 'file') ~= 2

        return;
    end


    str2num_local = ...
        @(s) str2double( ...
            strrep( ...
                char(s), ...
                ',', ...
                '.'));


    % ==============================================================
    % Variables temporaires
    % ==============================================================

    pmt_red = NaN;
    pmt_green = NaN;
    pmt_blue = NaN;

    electroporated_channel = '';


    try

        xmlDoc = ...
            xmlread( ...
                xml_file);

        rootNode = ...
            xmlDoc.getDocumentElement();


        % ==========================================================
        % Heure acquisition
        % ==========================================================

        if ~isempty(rootNode) && ...
                rootNode.hasAttribute('date')

            date_str = ...
                char( ...
                    rootNode.getAttribute( ...
                        'date'));

            split_date = ...
                strsplit( ...
                    date_str);

            if numel(split_date) > 1

                meta.RecordingTime = ...
                    split_date{2};

                if numel(split_date) > 2

                    meta.RecordingTime = ...
                        [ ...
                            meta.RecordingTime ...
                            ' ' ...
                            split_date{3} ...
                        ];
                end
            end
        end


        % ==========================================================
        % Paramètres globaux
        % ==========================================================

        pvNodes = ...
            xmlDoc.getElementsByTagName( ...
                'PVStateValue');


        for i = 0:pvNodes.getLength-1

            currentNode = ...
                pvNodes.item(i);

            key = ...
                char( ...
                    currentNode.getAttribute( ...
                        'key'));


            switch key

                case 'pixelsPerLine'

                    meta.PixelsPerLine = ...
                        str2num_local( ...
                            currentNode.getAttribute( ...
                                'value'));


                case 'linesPerFrame'

                    meta.LinesPerFrame = ...
                        str2num_local( ...
                            currentNode.getAttribute( ...
                                'value'));


                case 'opticalZoom'

                    meta.OpticalZoom = ...
                        str2num_local( ...
                            currentNode.getAttribute( ...
                                'value'));


                case 'objectiveLens'

                    meta.ObjectiveLens = ...
                        char( ...
                            currentNode.getAttribute( ...
                                'value'));


                case 'micronsPerPixel'

                    [ ...
                        meta.PixelSizeX_um, ...
                        meta.PixelSizeY_um ...
                    ] = ...
                        get_zseries_indexed_xy( ...
                            currentNode);


                    if isfinite(meta.PixelSizeX_um) && ...
                            isfinite(meta.PixelSizeY_um)

                        meta.PixelSize_um = ...
                            mean( ...
                                [ ...
                                    meta.PixelSizeX_um, ...
                                    meta.PixelSizeY_um ...
                                ]);

                    elseif isfinite(meta.PixelSizeX_um)

                        meta.PixelSize_um = ...
                            meta.PixelSizeX_um;

                    elseif isfinite(meta.PixelSizeY_um)

                        meta.PixelSize_um = ...
                            meta.PixelSizeY_um;
                    end


                case 'laserWavelength'

                    meta.LaserWavelength_nm = ...
                        get_zseries_indexed_value( ...
                            currentNode, ...
                            '0');


                case 'pmtGain'

                    pmt_red = ...
                        get_zseries_indexed_value_by_description( ...
                            currentNode, ...
                            'Red');

                    pmt_green = ...
                        get_zseries_indexed_value_by_description( ...
                            currentNode, ...
                            'Green');

                    pmt_blue = ...
                        get_zseries_indexed_value_by_description( ...
                            currentNode, ...
                            'Blue');
            end
        end


        % ==========================================================
        % Taille image
        % ==========================================================

        if isfinite(meta.PixelsPerLine) && ...
                isfinite(meta.LinesPerFrame)

            meta.ImageSize = ...
                sprintf( ...
                    '%d x %d', ...
                    meta.PixelsPerLine, ...
                    meta.LinesPerFrame);
        end


        % ==========================================================
        % Recherche de la séquence ZSeries
        % ==========================================================

        seqNodes = ...
            xmlDoc.getElementsByTagName( ...
                'Sequence');

        zseriesNode = [];


        for s = 0:seqNodes.getLength-1

            seqNode = ...
                seqNodes.item(s);

            if ~seqNode.hasAttribute('type')
                continue;
            end

            seqType = ...
                char( ...
                    seqNode.getAttribute( ...
                        'type'));

            if contains( ...
                    seqType, ...
                    'ZSeries', ...
                    'IgnoreCase', ...
                    true)

                zseriesNode = ...
                    seqNode;

                break;
            end
        end


        if isempty(zseriesNode)

            fprintf( ...
                'No ZSeries sequence found in XML:\n%s\n', ...
                xml_file);

            return;
        end


        % ==========================================================
        % Frames du ZSeries
        % ==========================================================

        frameNodes = ...
            zseriesNode.getElementsByTagName( ...
                'Frame');

        nFrames = ...
            frameNodes.getLength;


        meta.NumSlices = ...
            nFrames;


        if nFrames == 0
            return;
        end


        z_positions = ...
            nan(1,nFrames);

        x_positions = ...
            nan(1,nFrames);

        y_positions = ...
            nan(1,nFrames);

        laser_power = ...
            nan(1,nFrames);


        % ==========================================================
        % Une Frame = une coupe Z
        % ==========================================================

        for f = 0:nFrames-1

            frameNode = ...
                frameNodes.item(f);


            % ======================================================
            % Index du plan
            % ======================================================

            if frameNode.hasAttribute('index')

                plane_idx = ...
                    str2double( ...
                        char( ...
                            frameNode.getAttribute( ...
                                'index')));

            else

                plane_idx = ...
                    f + 1;
            end


            if ~isfinite(plane_idx) || ...
                    plane_idx < 1 || ...
                    plane_idx > nFrames

                plane_idx = ...
                    f + 1;
            end


            % ======================================================
            % Identifier le canal acquis
            % ======================================================

            fileNodes = ...
                frameNode.getElementsByTagName( ...
                    'File');


            for c = 0:fileNodes.getLength-1

                fileNode = ...
                    fileNodes.item(c);


                if isempty(electroporated_channel) && ...
                        fileNode.hasAttribute( ...
                            'channelName')

                    electroporated_channel = ...
                        char( ...
                            fileNode.getAttribute( ...
                                'channelName'));
                end
            end


            % ======================================================
            % Paramètres propres à cette coupe
            % ======================================================

            pvFrameNodes = ...
                frameNode.getElementsByTagName( ...
                    'PVStateValue');


            for p = 0:pvFrameNodes.getLength-1

                pvNode = ...
                    pvFrameNodes.item(p);

                key = ...
                    char( ...
                        pvNode.getAttribute( ...
                            'key'));


                switch key

                    % ==============================================
                    % Position XYZ
                    % ==============================================

                    case 'positionCurrent'

                        [ ...
                            x, ...
                            y, ...
                            z ...
                        ] = ...
                            get_zseries_position_xyz( ...
                                pvNode);


                        if isfinite(x)

                            x_positions(plane_idx) = ...
                                x;
                        end


                        if isfinite(y)

                            y_positions(plane_idx) = ...
                                y;
                        end


                        if isfinite(z)

                            z_positions(plane_idx) = ...
                                z;
                        end


                    % ==============================================
                    % Puissance Pockels du plan
                    % ==============================================

                    case 'laserPower'

                        value = ...
                            get_zseries_indexed_value( ...
                                pvNode, ...
                                '0');


                        if isfinite(value)

                            laser_power(plane_idx) = ...
                                value;
                        end
                end
            end
        end


        % ==========================================================
        % PMT du canal réellement acquis
        % ==========================================================

        switch lower( ...
                electroporated_channel)

            case 'red'

                meta.PMTGain_Electroporated = ...
                    pmt_red;

            case 'green'

                meta.PMTGain_Electroporated = ...
                    pmt_green;

            case 'blue'

                meta.PMTGain_Electroporated = ...
                    pmt_blue;
        end


        % ==========================================================
        % Position X / Y
        %
        % Normalement constantes durant tout le ZSeries.
        % ==============================================================

        valid_x = ...
            x_positions( ...
                isfinite(x_positions));

        valid_y = ...
            y_positions( ...
                isfinite(y_positions));


        if ~isempty(valid_x)

            meta.PositionX_um = ...
                median(valid_x);
        end


        if ~isempty(valid_y)

            meta.PositionY_um = ...
                median(valid_y);
        end


        % ==========================================================
        % Positions Z
        % ==========================================================

        meta.ZPositions = ...
            zseries_vector_to_string( ...
                z_positions);


        valid_idx = ...
            find( ...
                isfinite(z_positions));


        if ~isempty(valid_idx)

            valid_z = ...
                z_positions(valid_idx);


            % ------------------------------------------------------
            % Début / fin = ordre d'acquisition
            % ------------------------------------------------------

            meta.ZStart_um = ...
                valid_z(1);

            meta.ZEnd_um = ...
                valid_z(end);


            % ------------------------------------------------------
            % Étendue totale
            % ------------------------------------------------------

            meta.ZSpan_um = ...
                abs( ...
                    meta.ZEnd_um - ...
                    meta.ZStart_um);


            % ------------------------------------------------------
            % Pas Z
            % ------------------------------------------------------

            if numel(valid_z) > 1

                dz = ...
                    diff(valid_z);

                valid_dz = ...
                    dz( ...
                        isfinite(dz) & ...
                        abs(dz) > 1e-9);


                if ~isempty(valid_dz)

                    meta.ZStep_um = ...
                        median( ...
                            abs(valid_dz));


                    % --------------------------------------------------
                    % Direction de la pile
                    % --------------------------------------------------

                    if all(valid_dz > 0)

                        meta.ZDirection = ...
                            'ascending';


                    elseif all(valid_dz < 0)

                        meta.ZDirection = ...
                            'descending';


                    else

                        meta.ZDirection = ...
                            'mixed';
                    end
                end
            end
        end


        % ==========================================================
        % Puissance laser plan par plan
        % ==========================================================

        meta.LaserPowerByPlane_Pockels = ...
            zseries_vector_to_string( ...
                laser_power);


        valid_power = ...
            laser_power( ...
                isfinite(laser_power));


        if ~isempty(valid_power)

            meta.LaserPowerMin_Pockels = ...
                min(valid_power);

            meta.LaserPowerMax_Pockels = ...
                max(valid_power);
        end


        % ==========================================================
        % Gradient puissance laser / profondeur
        %
        % Régression linéaire :
        %
        %     P = a * Z + b
        %
        % a :
        %     Pockels / µm
        % ==========================================================

        valid_gradient_idx = ...
            isfinite(z_positions) & ...
            isfinite(laser_power);


        if nnz(valid_gradient_idx) >= 2

            z_fit = ...
                z_positions( ...
                    valid_gradient_idx);

            power_fit = ...
                laser_power( ...
                    valid_gradient_idx);


            if max(z_fit) > min(z_fit)

                coeff = ...
                    polyfit( ...
                        z_fit, ...
                        power_fit, ...
                        1);

                meta.LaserPowerGradient_Pockels_per_um = ...
                    coeff(1);
            end
        end


    catch ME

        fprintf( ...
            'Erreur lecture ZSeries metadata : %s\n', ...
            ME.message);
    end
end


%% ========================================================================
% XY INDEXED VALUES
% ========================================================================

function [x, y] = ...
        get_zseries_indexed_xy(node)

    x = NaN;
    y = NaN;


    idxNodes = ...
        node.getElementsByTagName( ...
            'IndexedValue');


    for j = 0:idxNodes.getLength-1

        idxNode = ...
            idxNodes.item(j);

        axis_name = ...
            char( ...
                idxNode.getAttribute( ...
                    'index'));

        value = ...
            str2double( ...
                char( ...
                    idxNode.getAttribute( ...
                        'value')));


        if strcmp(axis_name, 'XAxis')

            x = ...
                value;

        elseif strcmp(axis_name, 'YAxis')

            y = ...
                value;
        end
    end
end


%% ========================================================================
% INDEXED VALUE
% ========================================================================

function value = ...
        get_zseries_indexed_value( ...
            node, ...
            wanted_index)

    value = NaN;


    idxNodes = ...
        node.getElementsByTagName( ...
            'IndexedValue');


    for j = 0:idxNodes.getLength-1

        idxNode = ...
            idxNodes.item(j);


        if strcmp( ...
                char( ...
                    idxNode.getAttribute( ...
                        'index')), ...
                wanted_index)

            value = ...
                str2double( ...
                    char( ...
                        idxNode.getAttribute( ...
                            'value')));

            return;
        end
    end
end


%% ========================================================================
% INDEXED VALUE BY DESCRIPTION
% ========================================================================

function value = ...
        get_zseries_indexed_value_by_description( ...
            node, ...
            wanted_description)

    value = NaN;


    idxNodes = ...
        node.getElementsByTagName( ...
            'IndexedValue');


    for j = 0:idxNodes.getLength-1

        idxNode = ...
            idxNodes.item(j);


        if ~idxNode.hasAttribute( ...
                'description')

            continue;
        end


        description = ...
            char( ...
                idxNode.getAttribute( ...
                    'description'));


        if strcmpi( ...
                description, ...
                wanted_description)

            value = ...
                str2double( ...
                    char( ...
                        idxNode.getAttribute( ...
                            'value')));

            return;
        end
    end
end


%% ========================================================================
% POSITION XYZ
% ========================================================================

function [x, y, z] = ...
        get_zseries_position_xyz(node)

    x = NaN;
    y = NaN;
    z = NaN;


    subNodes = ...
        node.getElementsByTagName( ...
            'SubindexedValues');


    z_focus = NaN;
    etl_raw = NaN;


    for j = 0:subNodes.getLength-1

        subNode = ...
            subNodes.item(j);

        axis_name = ...
            char( ...
                subNode.getAttribute( ...
                    'index'));

        valNodes = ...
            subNode.getElementsByTagName( ...
                'SubindexedValue');


        for v = 0:valNodes.getLength-1

            valNode = ...
                valNodes.item(v);

            value = ...
                str2double( ...
                    char( ...
                        valNode.getAttribute( ...
                            'value')));


            if strcmp(axis_name, 'XAxis')

                x = ...
                    value;


            elseif strcmp(axis_name, 'YAxis')

                y = ...
                    value;


            elseif strcmp(axis_name, 'ZAxis')

                description = '';

                if valNode.hasAttribute( ...
                        'description')

                    description = ...
                        char( ...
                            valNode.getAttribute( ...
                                'description'));
                end


                subindex = '';

                if valNode.hasAttribute( ...
                        'subindex')

                    subindex = ...
                        char( ...
                            valNode.getAttribute( ...
                                'subindex'));
                end


                if contains( ...
                        description, ...
                        'Z Focus') || ...
                        strcmp( ...
                            subindex, ...
                            '0')

                    z_focus = ...
                        value;


                elseif contains( ...
                        description, ...
                        'Optotune') || ...
                        strcmp( ...
                            subindex, ...
                            '1')

                    etl_raw = ...
                        value;
                end
            end
        end
    end


    % ==============================================================
    % Même convention utilisée actuellement pour les autres metadata :
    %
    % Z effectif = Z Focus + Optotune / 1000
    % ==============================================================

    if isfinite(z_focus)

        if ~isfinite(etl_raw)

            etl_raw = ...
                0;
        end


        if abs(etl_raw) < 1e-6

            etl_raw = ...
                0;
        end


        z = ...
            z_focus + ...
            etl_raw / 1000;
    end
end


%% ========================================================================
% VECTOR -> STRING
% ========================================================================

function str = ...
        zseries_vector_to_string(v)

    if isempty(v)

        str = '';
        return;
    end


    v = ...
        v(:).';


    parts = ...
        cell( ...
            1, ...
            numel(v));


    for i = 1:numel(v)

        if isnan(v(i))

            parts{i} = ...
                'NaN';

        else

            parts{i} = ...
                sprintf( ...
                    '%.4f', ...
                    v(i));
        end
    end


    str = ...
        strjoin( ...
            parts, ...
            ' ');
end