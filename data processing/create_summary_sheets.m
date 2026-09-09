function recap_all = create_summary_sheets(selected_groups)

recap_all = struct();

if nargin < 1 || isempty(selected_groups)
    return;
end

type_names = fieldnames(selected_groups);

for t = 1:numel(type_names)

    current_type = type_names{t};
    recap_all.(current_type) = struct([]);

    for k = 1:numel(selected_groups.(current_type))

        current_group = ...
            selected_groups.(current_type)(k);

        % =========================================================
        % Vérifications structure
        % =========================================================

        if ~isfield(current_group, 'metadata') || ...
                ~isstruct(current_group.metadata) || ...
                ~isfield(current_group.metadata, 'gcamp_plane')

            fprintf( ...
                'Pas de metadata.gcamp_plane pour %s animal %d -> skip.\n', ...
                current_type, ...
                k);

            continue;
        end

        metadata = ...
            current_group.metadata.gcamp_plane;

        if ~isfield(current_group, 'paths') || ...
                ~isstruct(current_group.paths)

            fprintf( ...
                'Pas de paths pour %s animal %d -> skip.\n', ...
                current_type, ...
                k);

            continue;
        end

        current_paths = ...
            current_group.paths;

        % =========================================================
        % Animal
        % =========================================================

        animal_name = '';

        if isfield(current_group, 'animal') && ...
                ~isempty(current_group.animal)

            animal_name = ...
                char(string(current_group.animal));
        end

        % =========================================================
        % Nombre de recordings
        % =========================================================

        nRec = 0;

        if isfield(metadata, 'Date') && ...
                ~isempty(metadata.Date)

            nRec = ...
                max( ...
                    nRec, ...
                    numel(metadata.Date));
        end

        if isfield(current_group, 'dates') && ...
                ~isempty(current_group.dates)

            nRec = ...
                max( ...
                    nRec, ...
                    numel(current_group.dates));
        end

        if isfield(current_paths, 'gcamp_root') && ...
                ~isempty(current_paths.gcamp_root)

            nRec = ...
                max( ...
                    nRec, ...
                    numel(current_paths.gcamp_root));
        end

        if nRec == 0

            fprintf( ...
                'Aucun recording pour %s | %s -> skip.\n', ...
                current_type, ...
                animal_name);

            continue;
        end

        % =========================================================
        % Recaps temporaires
        % =========================================================

        recap_tmp = ...
            cell(1, nRec);

        % =========================================================
        % Boucle recordings
        % =========================================================

        for idx = 1:nRec

            % -----------------------------------------------------
            % Dossier de sortie du recording
            % -----------------------------------------------------

            output_folder = '';

            if isfield(current_paths, 'gcamp_root') && ...
                    ~isempty(current_paths.gcamp_root) && ...
                    numel(current_paths.gcamp_root) >= idx && ...
                    ~isempty(current_paths.gcamp_root{idx})

                output_folder = ...
                    current_paths.gcamp_root{idx};
            end

            if isempty(output_folder)

                fprintf( ...
                    'Pas de gcamp_root pour %s | %s | rec %d -> skip.\n', ...
                    current_type, ...
                    animal_name, ...
                    idx);

                continue;
            end

            % -----------------------------------------------------
            % Création / chargement fiche
            % -----------------------------------------------------

            recap_tmp{idx} = ...
                create_one_recording_summary_sheet( ...
                    metadata, ...
                    output_folder, ...
                    current_type, ...
                    animal_name, ...
                    idx);
        end

        % =========================================================
        % Conversion en tableau de structures
        % =========================================================

        valid_recap = ...
            ~cellfun( ...
                @isempty, ...
                recap_tmp);

        if any(valid_recap)

            recap_all.(current_type)(k).recap = ...
                [recap_tmp{valid_recap}];

        else

            recap_all.(current_type)(k).recap = ...
                struct([]);
        end
    end
end

end


%% ========================================================================
function recap = create_one_recording_summary_sheet( ...
        metadata, ...
        output_folder, ...
        current_type, ...
        animal_name, ...
        idx)

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% =========================================================
% Date
% =========================================================

date_name = ...
    get_meta_idx( ...
        metadata, ...
        'Date', ...
        idx);

output_file = ...
    fullfile( ...
        output_folder, ...
        sprintf( ...
            'recording_summary_%s_rec%d.txt', ...
            value_to_filename(date_name), ...
            idx));

% =========================================================
% Construction du recap
% =========================================================
%
% IMPORTANT :
% recap est toujours construit avec exactement les mêmes
% fields, que la fiche existe déjà ou non.
% =========================================================

recap = struct();

recap.comment = ...
    '';

recap.date_name = ...
    date_name;

recap.animal_name = ...
    animal_name;

recap.recording_time = ...
    get_meta_idx(metadata, 'RecordingTime', idx);

recap.time_minutes = ...
    get_meta_idx(metadata, 'TimeMinutes', idx);

recap.num_frames = ...
    get_meta_idx(metadata, 'NumFrames', idx);

recap.active_mode = ...
    get_meta_idx(metadata, 'ActiveMode', idx);

recap.bit_depth = ...
    get_meta_idx(metadata, 'BitDepth', idx);

recap.sampling_rate = ...
    get_meta_idx(metadata, 'SamplingRate', idx);

recap.frame_period = ...
    get_meta_idx(metadata, 'FramePeriod', idx);

recap.sampling_rate_plane = ...
    get_meta_idx(metadata, 'SamplingRatePlane', idx);

recap.interplane_delay_s = ...
    get_meta_idx(metadata, 'InterplaneDelay_s', idx);

recap.pixels_per_line = ...
    get_meta_idx(metadata, 'PixelsPerLine', idx);

recap.lines_per_frame = ...
    get_meta_idx(metadata, 'LinesPerFrame', idx);

recap.image_size = ...
    get_meta_idx(metadata, 'ImageSize', idx);

recap.pixel_size_x_um = ...
    get_meta_idx(metadata, 'PixelSizeX_um', idx);

recap.pixel_size_y_um = ...
    get_meta_idx(metadata, 'PixelSizeY_um', idx);

recap.pixel_size_um = ...
    get_meta_idx(metadata, 'PixelSize_um', idx);

recap.optical_zoom = ...
    get_meta_idx(metadata, 'OpticalZoom', idx);

recap.objective_lens = ...
    get_meta_idx(metadata, 'ObjectiveLens', idx);

recap.objective_lens_mag = ...
    get_meta_idx(metadata, 'ObjectiveLensMag', idx);

recap.objective_lens_na = ...
    get_meta_idx(metadata, 'ObjectiveLensNA', idx);

recap.position_x_um = ...
    get_meta_idx(metadata, 'PositionX_um', idx);

recap.position_y_um = ...
    get_meta_idx(metadata, 'PositionY_um', idx);

recap.position_z = ...
    get_meta_idx(metadata, 'PositionZ', idx);

recap.num_planes = ...
    get_meta_idx(metadata, 'NumPlanes', idx);

recap.z_step_um = ...
    get_meta_idx(metadata, 'ZStep_um', idx);

recap.z_min_um = ...
    get_meta_idx(metadata, 'ZMin_um', idx);

recap.z_max_um = ...
    get_meta_idx(metadata, 'ZMax_um', idx);

recap.dwell_time_us = ...
    get_meta_idx(metadata, 'DwellTime_us', idx);

recap.scan_line_period_s = ...
    get_meta_idx(metadata, 'ScanLinePeriod_s', idx);

recap.samples_per_pixel = ...
    get_meta_idx(metadata, 'SamplesPerPixel', idx);

recap.laser_wavelength_nm = ...
    get_meta_idx(metadata, 'LaserWavelength_nm', idx);

recap.laser_power_pockels = ...
    get_meta_idx(metadata, 'LaserPower_Pockels', idx);

recap.laser_power_by_plane = ...
    get_meta_idx(metadata, 'LaserPowerByPlane_Pockels', idx);

recap.pmt_gain_red = ...
    get_meta_idx(metadata, 'PMTGain_Red', idx);

recap.pmt_gain_green = ...
    get_meta_idx(metadata, 'PMTGain_Green', idx);

recap.pmt_gain_blue = ...
    get_meta_idx(metadata, 'PMTGain_Blue', idx);

recap.channel_names = ...
    get_meta_idx(metadata, 'ChannelNames', idx);

recap.num_channels = ...
    get_meta_idx(metadata, 'NumChannels', idx);

recap.bidirectional_z = ...
    get_meta_idx(metadata, 'BidirectionalZ', idx);

recap.summary_file = ...
    output_file;

recap.already_exists = ...
    exist(output_file, 'file') == 2;

% =========================================================
% Gestion du commentaire
% =========================================================

rewrite_file = ...
    true;

if recap.already_exists

    % -----------------------------------------------------
    % Charger commentaire existant
    % -----------------------------------------------------

    existing_comment = ...
        read_summary_comment( ...
            output_file);

    recap.comment = ...
        existing_comment;

    % -----------------------------------------------------
    % Commentaire déjà présent
    % -----------------------------------------------------

    if ~isempty(strtrim(existing_comment))

        dlg = ...
            helpdlg( ...
                sprintf( ...
                    'Commentaire :\n\n%s', ...
                    existing_comment), ...
                sprintf( ...
                    '%s | %s | %s', ...
                    current_type, ...
                    animal_name, ...
                    value_to_string(date_name)));

        % Bloque le pipeline jusqu'à clic sur OK
        uiwait(dlg);

        fprintf( ...
            'Summary déjà existant avec commentaire -> conservation : %s\n', ...
            output_file);

        rewrite_file = ...
            false;

    else

        % -------------------------------------------------
        % Fiche existante mais commentaire vide
        % -------------------------------------------------

        fprintf( ...
            'Summary existant mais commentaire vide : %s\n', ...
            output_file);

        comment_answer = ...
            inputdlg( ...
                sprintf( ...
                    'Commentaire pour %s | %s | %s :', ...
                    current_type, ...
                    animal_name, ...
                    value_to_string(date_name)), ...
                'Recording comment', ...
                [5 80]);

        % -------------------------------------------------
        % Cancel
        % -------------------------------------------------

        if isempty(comment_answer)

            fprintf( ...
                'Commentaire annulé -> fiche existante conservée sans modification.\n');

            rewrite_file = ...
                false;

        else

            recap.comment = ...
                comment_answer{1};

            rewrite_file = ...
                true;
        end
    end

else

    % =====================================================
    % Nouvelle fiche
    % =====================================================

    comment_answer = ...
        inputdlg( ...
            sprintf( ...
                'Commentaire pour %s | %s | %s :', ...
                current_type, ...
                animal_name, ...
                value_to_string(date_name)), ...
            'Recording comment', ...
            [5 80]);

    % -----------------------------------------------------
    % Cancel = commentaire vide
    % -----------------------------------------------------

    if isempty(comment_answer)

        recap.comment = ...
            '';

    else

        recap.comment = ...
            comment_answer{1};
    end
end

% =========================================================
% Ne pas réécrire si inutile
% =========================================================

if ~rewrite_file
    return;
end

% =========================================================
% Écriture / réécriture
% =========================================================

fid = ...
    fopen( ...
        output_file, ...
        'w');

if fid == -1

    error( ...
        'Impossible de créer le fichier : %s', ...
        output_file);
end

fprintf(fid, 'FICHE RÉCAPITULATIVE ENREGISTREMENT\n');
fprintf(fid, '===================================\n\n');

fprintf(fid, 'Type                 : %s\n', current_type);
fprintf(fid, 'Animal               : %s\n', animal_name);
fprintf(fid, 'Date                 : %s\n', value_to_string(date_name));
fprintf(fid, 'Enregistrement       : %d\n', idx);
fprintf(fid, 'Dossier sauvegarde   : %s\n\n', output_folder);

fprintf(fid, 'COMMENTAIRES\n');
fprintf(fid, '------------\n');
fprintf(fid, '%s\n\n', value_to_string(recap.comment));

fprintf(fid, 'INFOS ENREGISTREMENT\n');
fprintf(fid, '--------------------\n');
fprintf(fid, 'Recording time       : %s\n', value_to_string(recap.recording_time));
fprintf(fid, 'Durée acquisition    : %s min\n', value_to_string(recap.time_minutes));
fprintf(fid, 'Nombre de frames     : %s\n\n', value_to_string(recap.num_frames));

fprintf(fid, 'ACQUISITION\n');
fprintf(fid, '-----------\n');
fprintf(fid, 'Active mode          : %s\n', value_to_string(recap.active_mode));
fprintf(fid, 'Bit depth            : %s\n\n', value_to_string(recap.bit_depth));

fprintf(fid, 'TEMPORALITÉ\n');
fprintf(fid, '-----------\n');
fprintf(fid, 'Sampling rate total  : %s Hz\n', value_to_string(recap.sampling_rate));
fprintf(fid, 'Frame period         : %s s\n', value_to_string(recap.frame_period));
fprintf(fid, 'Sampling rate/plane  : %s Hz\n', value_to_string(recap.sampling_rate_plane));
fprintf(fid, 'Délai inter-plan     : %s s\n\n', value_to_string(recap.interplane_delay_s));

fprintf(fid, 'IMAGE / RÉSOLUTION\n');
fprintf(fid, '------------------\n');
fprintf(fid, 'Pixels per line      : %s\n', value_to_string(recap.pixels_per_line));
fprintf(fid, 'Lines per frame      : %s\n', value_to_string(recap.lines_per_frame));
fprintf(fid, 'Image size           : %s\n', value_to_string(recap.image_size));
fprintf(fid, 'Pixel size X         : %s µm/pixel\n', value_to_string(recap.pixel_size_x_um));
fprintf(fid, 'Pixel size Y         : %s µm/pixel\n', value_to_string(recap.pixel_size_y_um));
fprintf(fid, 'Pixel size moyen     : %s µm/pixel\n\n', value_to_string(recap.pixel_size_um));

fprintf(fid, 'OPTIQUE\n');
fprintf(fid, '-------\n');
fprintf(fid, 'Optical zoom         : %s\n', value_to_string(recap.optical_zoom));
fprintf(fid, 'Objective lens       : %s\n', value_to_string(recap.objective_lens));
fprintf(fid, 'Objective mag        : %s\n', value_to_string(recap.objective_lens_mag));
fprintf(fid, 'Objective NA         : %s\n\n', value_to_string(recap.objective_lens_na));

fprintf(fid, 'POSITION / MULTIPLAN\n');
fprintf(fid, '--------------------\n');
fprintf(fid, 'Position X           : %s µm\n', value_to_string(recap.position_x_um));
fprintf(fid, 'Position Y           : %s µm\n', value_to_string(recap.position_y_um));
fprintf(fid, 'Position Z           : %s µm\n', value_to_string(recap.position_z));
fprintf(fid, 'Nombre de plans      : %s\n', value_to_string(recap.num_planes));
fprintf(fid, 'Z step               : %s µm\n', value_to_string(recap.z_step_um));
fprintf(fid, 'Z min                : %s µm\n', value_to_string(recap.z_min_um));
fprintf(fid, 'Z max                : %s µm\n', value_to_string(recap.z_max_um));
fprintf(fid, 'Bidirectional Z      : %s\n\n', value_to_string(recap.bidirectional_z));

fprintf(fid, 'BALAYAGE\n');
fprintf(fid, '--------\n');
fprintf(fid, 'Dwell time           : %s µs\n', value_to_string(recap.dwell_time_us));
fprintf(fid, 'Scan line period     : %s s\n', value_to_string(recap.scan_line_period_s));
fprintf(fid, 'Samples per pixel    : %s\n\n', value_to_string(recap.samples_per_pixel));

fprintf(fid, 'LASER / PMT\n');
fprintf(fid, '-----------\n');
fprintf(fid, 'Laser wavelength     : %s nm\n', value_to_string(recap.laser_wavelength_nm));
fprintf(fid, 'Laser power Pockels  : %s\n', value_to_string(recap.laser_power_pockels));
fprintf(fid, 'Laser power / plane  : %s\n', value_to_string(recap.laser_power_by_plane));
fprintf(fid, 'PMT gain Red         : %s\n', value_to_string(recap.pmt_gain_red));
fprintf(fid, 'PMT gain Green       : %s\n', value_to_string(recap.pmt_gain_green));
fprintf(fid, 'PMT gain Blue        : %s\n\n', value_to_string(recap.pmt_gain_blue));

fprintf(fid, 'CANAUX\n');
fprintf(fid, '------\n');
fprintf(fid, 'Channel names        : %s\n', value_to_string(recap.channel_names));
fprintf(fid, 'Nombre de channels   : %s\n\n', value_to_string(recap.num_channels));

% =========================================================
% Source metadata
% =========================================================

if isfield(metadata, 'source_file') && ...
        ~isempty(metadata.source_file)

    fprintf(fid, 'SOURCE METADATA\n');
    fprintf(fid, '---------------\n');
    fprintf(fid, '%s\n', value_to_string(metadata.source_file));
end

fclose(fid);

% =========================================================
% Message console
% =========================================================

if recap.already_exists

    fprintf( ...
        'Fiche mise à jour avec commentaire : %s\n', ...
        output_file);

else

    fprintf( ...
        'Fiche sauvegardée : %s\n', ...
        output_file);
end

end


%% ========================================================================
function comment_text = read_summary_comment(output_file)

comment_text = '';

if exist(output_file, 'file') ~= 2
    return;
end

txt = ...
    fileread( ...
        output_file);

lines = ...
    regexp( ...
        txt, ...
        '\r\n|\n|\r', ...
        'split');

% =========================================================
% Trouver section COMMENTAIRES
% =========================================================

comment_idx = ...
    find( ...
        strcmp(strtrim(lines), 'COMMENTAIRES'), ...
        1, ...
        'first');

if isempty(comment_idx)
    return;
end

% COMMENTAIRES
% ------------
% commentaire
%
% INFOS ENREGISTREMENT

start_idx = ...
    comment_idx + 2;

if start_idx > numel(lines)
    return;
end

% =========================================================
% Trouver section suivante
% =========================================================

end_idx = ...
    numel(lines);

for i = start_idx:numel(lines)

    if strcmp(strtrim(lines{i}), 'INFOS ENREGISTREMENT')

        end_idx = ...
            i - 1;

        break;
    end
end

% =========================================================
% Récupérer commentaire
% =========================================================

comment_lines = ...
    lines(start_idx:end_idx);

% ---------------------------------------------------------
% Supprimer lignes vides au début
% ---------------------------------------------------------

while ~isempty(comment_lines) && ...
        isempty(strtrim(comment_lines{1}))

    comment_lines(1) = [];
end

% ---------------------------------------------------------
% Supprimer lignes vides à la fin
% ---------------------------------------------------------

while ~isempty(comment_lines) && ...
        isempty(strtrim(comment_lines{end}))

    comment_lines(end) = [];
end

if isempty(comment_lines)
    return;
end

comment_text = ...
    strjoin( ...
        comment_lines, ...
        newline);

% =========================================================
% "NA" = ancien commentaire vide
% =========================================================

if strcmpi(strtrim(comment_text), 'NA')

    comment_text = ...
        '';
end

end


%% ========================================================================
function value = get_meta_idx(metadata, field, idx)

value = [];

if ~isstruct(metadata) || ...
        ~isfield(metadata, field)

    return;
end

x = ...
    metadata.(field);

if iscell(x)

    if numel(x) >= idx

        value = ...
            x{idx};
    end

else

    if numel(x) >= idx

        value = ...
            x(idx);
    end
end

end


%% ========================================================================
function filename_str = value_to_filename(value)

filename_str = ...
    value_to_string(value);

if strcmp(filename_str, 'NA')

    filename_str = ...
        'unknown_date';
end

filename_str = ...
    regexprep( ...
        filename_str, ...
        '[^\w\-]', ...
        '_');

end


%% ========================================================================
function str = value_to_string(value)

if isempty(value)

    str = ...
        'NA';

elseif ischar(value)

    str = ...
        value;

elseif isstring(value)

    str = ...
        char(value);

elseif isnumeric(value) || ...
        islogical(value)

    if isscalar(value)

        str = ...
            num2str(value);

    else

        str = ...
            mat2str(value);
    end

elseif iscell(value)

    try

        str = ...
            strjoin( ...
                cellfun( ...
                    @value_to_string, ...
                    value, ...
                    'UniformOutput', ...
                    false), ...
                ', ');

    catch

        str = ...
            '[cell non affichable]';
    end

else

    str = ...
        '[format non reconnu]';
end

end