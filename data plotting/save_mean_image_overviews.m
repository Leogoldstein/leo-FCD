function save_mean_image_overviews( ...
    current_line, ...
    current_animal, ...
    current_dates, ...
    current_ages, ...
    current_automatic_selection, ...
    current_suite2p_group, ...
    gcamp_root_folders, ...
    current_output_folder, ...
    meanImgs_gcamp, ...
    alignedImgs_electroporated)

%SAVE_MEAN_IMAGE_OVERVIEWS
%
% Crée une figure par recording.
%
% Chaque ligne correspond à un plan.
%
% Le canal electroporated est déterminé automatiquement à partir de
% current_suite2p_group :
%
%   colonne 2 présente -> Electroporated affiché en rouge
%   sinon colonne 3     -> Electroporated affiché en bleu
%
% Si un canal electroporated existe :
%
%   Colonne 1 : GCaMP en vert
%   Colonne 2 : Electroporated en rouge ou bleu
%   Colonne 3 : Overlay
%
% Sinon :
%
%   Une seule colonne GCaMP.
%
% Sauvegarde :
%
%   - toujours dans gcamp_root_folders{m}
%   - dans current_output_folder uniquement si
%     current_automatic_selection ~= 0
%
% Aucun fichier existant n'est écrasé.


    if nargin < 10

        error( ...
            'save_mean_image_overviews:MissingInputs', ...
            'Ten input arguments are required.');
    end


    if isempty(meanImgs_gcamp) && ...
            isempty(alignedImgs_electroporated)

        fprintf('\n');
        fprintf('No mean image available for overview figures.\n');

        return;
    end


    % =============================================================
    % Identité
    % =============================================================

    line_name = ...
        normalize_text_mean_overview( ...
            current_line);

    animal_name = ...
        normalize_text_mean_overview( ...
            current_animal);

    current_output_folder = ...
        normalize_text_mean_overview( ...
            current_output_folder);

    line_clean = ...
        sanitize_filename_mean_overview( ...
            line_name);

    animal_clean = ...
        sanitize_filename_mean_overview( ...
            animal_name);


    % =============================================================
    % Couleur du canal electroporated
    %
    % Colonne 2 -> Red
    % Colonne 3 -> Blue
    % =============================================================

    electroporated_color_channel = [];
    electroporated_color_name = '';

    for c = [2 3]

        if c > size(current_suite2p_group, 2)
            continue;
        end

        current_column = ...
            current_suite2p_group(:, c);

        has_electroporated_data = ...
            any( ...
                cellfun( ...
                    @(x) ...
                        ~isempty(x) && ...
                        (~ischar(x) || ...
                         ~isempty(strtrim(x))), ...
                    current_column));

        if ~has_electroporated_data
            continue;
        end

        if c == 2

            electroporated_color_channel = 1;
            electroporated_color_name = 'Red';

        else

            electroporated_color_channel = 3;
            electroporated_color_name = 'Blue';
        end

        break;
    end


    num_recordings = ...
        max( ...
            numel(meanImgs_gcamp), ...
            numel(alignedImgs_electroporated));


    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MEAN IMAGE OVERVIEW FIGURES\n');
    fprintf('Line      : %s\n', line_name);
    fprintf('Animal    : %s\n', animal_name);
    fprintf('Recordings: %d\n', num_recordings);

    if isempty(electroporated_color_name)

        fprintf('Electroporated channel: unavailable\n');

    else

        fprintf( ...
            'Electroporated channel: %s\n', ...
            electroporated_color_name);
    end

    fprintf('============================================================\n');


    % =============================================================
    % Recordings
    % =============================================================

    for m = 1:num_recordings

        % =========================================================
        % Age
        % =========================================================

        age_name = ...
            get_age_name_mean_overview( ...
                current_ages, ...
                m);

        age_clean = ...
            sanitize_filename_mean_overview( ...
                age_name);


        % =========================================================
        % Date
        % =========================================================

        date_name = ...
            get_date_name_mean_overview( ...
                current_dates, ...
                m);

        date_clean = ...
            sanitize_filename_mean_overview( ...
                date_name);


        % =========================================================
        % Images du recording
        % =========================================================

        gcamp_images_m = ...
            get_recording_images_mean_overview( ...
                meanImgs_gcamp, ...
                m);

        electroporated_images_m = ...
            get_recording_images_mean_overview( ...
                alignedImgs_electroporated, ...
                m);

        num_planes = ...
            max( ...
                numel(gcamp_images_m), ...
                numel(electroporated_images_m));


        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('Recording %d/%d\n', m, num_recordings);
        fprintf('Date      : %s\n', date_name);
        fprintf('Age       : %s\n', age_name);
        fprintf('Planes    : %d\n', num_planes);
        fprintf('------------------------------------------------------------\n');


        if num_planes == 0

            fprintf('Status: no mean image available.\n');

            continue;
        end


        % =========================================================
        % Dossier local du recording
        %
        % Toujours utilisé, indépendamment de automatic_selection.
        % =========================================================

        output_root_folder = ...
            get_root_folder_mean_overview( ...
                gcamp_root_folders, ...
                m);

        local_png_path = '';
        local_destination_available = false;


        if isempty(output_root_folder)

            warning( ...
                'save_mean_image_overviews:MissingOutputFolder', ...
                ['Recording %d: gcamp_root_folders does not ' ...
                 'contain a valid output folder.'], ...
                m);

        else

            if ~isfolder(output_root_folder)

                try

                    mkdir(output_root_folder);

                catch ME

                    warning( ...
                        'save_mean_image_overviews:FolderCreationFailed', ...
                        ['Unable to create output folder for ' ...
                         'recording %d: %s'], ...
                        m, ...
                        ME.message);
                end
            end


            if isfolder(output_root_folder)

                local_png_path = ...
                    fullfile( ...
                        output_root_folder, ...
                        sprintf( ...
                            'Mean_images_%s_%s_%s.png', ...
                            animal_clean, ...
                            date_clean, ...
                            age_clean));

                local_destination_available = true;
            end
        end


        % =========================================================
        % Destination summary
        %
        % Uniquement pour automatic selection.
        % =========================================================

        summary_png_path = '';
        summary_destination_available = false;


        if current_automatic_selection

            % -----------------------------------------------------
            % Plans indexés à partir de 0 dans le nom
            % -----------------------------------------------------

            plane_numbers = ...
                0:(num_planes - 1);

            if isempty(plane_numbers)

                plane_clean = '';

            elseif numel(plane_numbers) == 1

                plane_clean = ...
                    sprintf( ...
                        'plane%d', ...
                        plane_numbers);

            else

                plane_clean = [ ...
                    'planes', ...
                    strjoin( ...
                        arrayfun( ...
                            @num2str, ...
                            plane_numbers, ...
                            'UniformOutput', false), ...
                        '-')];
            end


            name_parts = { ...
                line_clean, ...
                animal_clean, ...
                date_clean, ...
                age_clean, ...
                plane_clean};

            name_parts = ...
                name_parts( ...
                    ~cellfun( ...
                        @isempty, ...
                        name_parts));


            if isempty(name_parts)

                summary_base_name = ...
                    'mean_images_overview';

            else

                summary_base_name = [ ...
                    strjoin( ...
                        name_parts, ...
                        '_'), ...
                    '_mean_images_overview'];
            end


            if ~isempty(current_output_folder)

                if ~isfolder(current_output_folder)

                    try

                        mkdir(current_output_folder);

                    catch ME

                        warning( ...
                            'save_mean_image_overviews:SummaryFolderFailed', ...
                            ['Unable to create current_output_folder: ' ...
                             '%s'], ...
                            ME.message);
                    end
                end


                if isfolder(current_output_folder)

                    summary_png_path = ...
                        fullfile( ...
                            current_output_folder, ...
                            [summary_base_name '.png']);

                    summary_destination_available = true;
                end
            end
        end


        % =========================================================
        % Vérification indépendante des destinations
        % =========================================================

        local_exists = ...
            local_destination_available && ...
            isfile(local_png_path);

        summary_exists = ...
            summary_destination_available && ...
            isfile(summary_png_path);


        local_needs_save = ...
            local_destination_available && ...
            ~local_exists;

        summary_needs_save = ...
            summary_destination_available && ...
            ~summary_exists;


        if local_exists

            fprintf( ...
                'Local overview already exists:\n%s\n', ...
                local_png_path);
        end


        if summary_exists

            fprintf( ...
                'Summary overview already exists:\n%s\n', ...
                summary_png_path);
        end


        if ~local_destination_available && ...
                ~summary_destination_available

            warning( ...
                'save_mean_image_overviews:NoValidDestination', ...
                ['Recording %d: no valid output destination ' ...
                 'is available.'], ...
                m);

            continue;
        end


        if ~local_needs_save && ...
                ~summary_needs_save

            fprintf( ...
                ['Status: all available overview files already ' ...
                 'exist, figure skipped.\n']);

            continue;
        end


        % =========================================================
        % Charger les images par plan
        % =========================================================

        gcamp_planes = ...
            cell(num_planes, 1);

        electroporated_planes = ...
            cell(num_planes, 1);


        has_gcamp_by_plane = ...
            false(num_planes, 1);

        has_electroporated_by_plane = ...
            false(num_planes, 1);


        for p = 1:num_planes

            gcamp_planes{p} = ...
                get_plane_image_mean_overview( ...
                    gcamp_images_m, ...
                    p);

            electroporated_planes{p} = ...
                get_plane_image_mean_overview( ...
                    electroporated_images_m, ...
                    p);


            has_gcamp_by_plane(p) = ...
                ~isempty( ...
                    gcamp_planes{p});

            has_electroporated_by_plane(p) = ...
                ~isempty( ...
                    electroporated_planes{p});
        end


        valid_planes = ...
            has_gcamp_by_plane | ...
            has_electroporated_by_plane;


        if ~any(valid_planes)

            fprintf('Status: all planes are empty.\n');

            continue;
        end


        % Une image electroporated n'est affichée que si le canal
        % correspondant a réellement été identifié.
        has_any_electroporated = ...
            any(has_electroporated_by_plane) && ...
            ~isempty(electroporated_color_channel);


        if has_any_electroporated

            num_columns = 3;

        else

            num_columns = 1;
        end


        valid_plane_indices = ...
            find(valid_planes);

        num_valid_planes = ...
            numel(valid_plane_indices);


        % =========================================================
        % Dimensions figure
        % =========================================================

        tile_width = 480;
        tile_height = 420;

        figure_width = ...
            max( ...
                600, ...
                num_columns * tile_width);

        figure_height = ...
            max( ...
                500, ...
                num_valid_planes * tile_height + 100);


        fig = [];


        try

            fig = ...
                figure( ...
                    'Visible', 'off', ...
                    'Color', 'w', ...
                    'Units', 'pixels', ...
                    'Position', [ ...
                        100, ...
                        100, ...
                        figure_width, ...
                        figure_height]);


            layout = ...
                tiledlayout( ...
                    fig, ...
                    num_valid_planes, ...
                    num_columns, ...
                    'TileSpacing', 'compact', ...
                    'Padding', 'compact');


            % =====================================================
            % Une ligne par plan
            % =====================================================

            for row_index = 1:num_valid_planes

                p = ...
                    valid_plane_indices(row_index);

                mean_gcamp = ...
                    gcamp_planes{p};

                mean_electroporated = ...
                    electroporated_planes{p};

                has_gcamp = ...
                    has_gcamp_by_plane(p);

                has_electroporated = ...
                    has_electroporated_by_plane(p);


                % =================================================
                % GCaMP + Electroporated + Overlay
                % =================================================

                if has_any_electroporated

                    green_rgb = [];
                    electroporated_rgb = [];
                    overlay_rgb = [];


                    if has_gcamp

                        green_rgb = ...
                            create_single_channel_rgb( ...
                                mean_gcamp, ...
                                2);
                    end


                    if has_electroporated

                        electroporated_rgb = ...
                            create_single_channel_rgb( ...
                                mean_electroporated, ...
                                electroporated_color_channel);
                    end


                    if has_gcamp && ...
                            has_electroporated

                        [ ...
                            mean_gcamp_overlay, ...
                            mean_electroporated_overlay ...
                        ] = ...
                            match_mean_image_sizes( ...
                                mean_gcamp, ...
                                mean_electroporated);

                        overlay_rgb = ...
                            create_mean_image_overlay( ...
                                mean_gcamp_overlay, ...
                                mean_electroporated_overlay, ...
                                electroporated_color_channel);
                    end


                    % ---------------------------------------------
                    % GCaMP
                    % ---------------------------------------------

                    ax_gcamp = ...
                        nexttile(layout);


                    if has_gcamp

                        image( ...
                            ax_gcamp, ...
                            green_rgb);

                    else

                        show_empty_mean_image_panel( ...
                            ax_gcamp, ...
                            'GCaMP unavailable');
                    end


                    axis(ax_gcamp, 'image');
                    axis(ax_gcamp, 'off');


                    title( ...
                        ax_gcamp, ...
                        sprintf( ...
                            'Plane %d - GCaMP', ...
                            p - 1), ...
                        'Interpreter', 'none', ...
                        'FontSize', 13, ...
                        'FontWeight', 'bold');


                    % ---------------------------------------------
                    % Electroporated
                    % ---------------------------------------------

                    ax_electroporated = ...
                        nexttile(layout);


                    if has_electroporated

                        image( ...
                            ax_electroporated, ...
                            electroporated_rgb);

                    else

                        show_empty_mean_image_panel( ...
                            ax_electroporated, ...
                            'Electroporated unavailable');
                    end


                    axis(ax_electroporated, 'image');
                    axis(ax_electroporated, 'off');


                    title( ...
                        ax_electroporated, ...
                        sprintf( ...
                            'Plane %d - Electroporated (%s)', ...
                            p - 1, ...
                            electroporated_color_name), ...
                        'Interpreter', 'none', ...
                        'FontSize', 13, ...
                        'FontWeight', 'bold');


                    % ---------------------------------------------
                    % Overlay
                    % ---------------------------------------------

                    ax_overlay = ...
                        nexttile(layout);


                    if has_gcamp && ...
                            has_electroporated

                        image( ...
                            ax_overlay, ...
                            overlay_rgb);

                    else

                        show_empty_mean_image_panel( ...
                            ax_overlay, ...
                            'Overlay unavailable');
                    end


                    axis(ax_overlay, 'image');
                    axis(ax_overlay, 'off');


                    title( ...
                        ax_overlay, ...
                        sprintf( ...
                            'Plane %d - Overlay', ...
                            p - 1), ...
                        'Interpreter', 'none', ...
                        'FontSize', 13, ...
                        'FontWeight', 'bold');


                % =================================================
                % GCaMP seul
                % =================================================

                else

                    ax_gcamp = ...
                        nexttile(layout);


                    if has_gcamp

                        green_rgb = ...
                            create_single_channel_rgb( ...
                                mean_gcamp, ...
                                2);

                        image( ...
                            ax_gcamp, ...
                            green_rgb);

                    else

                        show_empty_mean_image_panel( ...
                            ax_gcamp, ...
                            'GCaMP unavailable');
                    end


                    axis(ax_gcamp, 'image');
                    axis(ax_gcamp, 'off');


                    title( ...
                        ax_gcamp, ...
                        sprintf( ...
                            'Plane %d - GCaMP', ...
                            p - 1), ...
                        'Interpreter', 'none', ...
                        'FontSize', 13, ...
                        'FontWeight', 'bold');
                end
            end


            % =====================================================
            % Titre général
            % =====================================================

            sgtitle( ...
                layout, ...
                sprintf( ...
                    '%s | %s | %s | %s', ...
                    line_name, ...
                    animal_name, ...
                    date_name, ...
                    age_name), ...
                'Interpreter', 'none', ...
                'FontSize', 16, ...
                'FontWeight', 'bold');


            % =====================================================
            % Sauvegarde locale
            % =====================================================

            if local_needs_save

                save_mean_overview_figure( ...
                    fig, ...
                    local_png_path);

                fprintf( ...
                    'Local overview saved:\n%s\n', ...
                    local_png_path);
            end


            % =====================================================
            % Sauvegarde summary
            % =====================================================

            if summary_needs_save

                same_destination = ...
                    local_destination_available && ...
                    strcmpi( ...
                        char(local_png_path), ...
                        char(summary_png_path));


                if same_destination

                    if ~local_needs_save

                        fprintf( ...
                            ['Summary destination is identical to ' ...
                             'the existing local destination.\n']);
                    end

                else

                    save_mean_overview_figure( ...
                        fig, ...
                        summary_png_path);

                    fprintf( ...
                        'Summary overview saved:\n%s\n', ...
                        summary_png_path);
                end
            end


            if isgraphics(fig)

                close(fig);
            end


        catch ME

            if ~isempty(fig) && ...
                    isgraphics(fig)

                close(fig);
            end


            warning( ...
                'save_mean_image_overviews:FigureCreationFailed', ...
                ['Recording %d: unable to create or save the ' ...
                 'mean-image overview figure: %s'], ...
                m, ...
                ME.message);
        end
    end


    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MEAN IMAGE OVERVIEW FIGURES COMPLETED\n');
    fprintf('Animal: %s\n', animal_name);
    fprintf('============================================================\n');
end


%% ========================================================================
function images = get_recording_images_mean_overview( ...
    all_images, ...
    recording_index)

    images = {};

    if isempty(all_images)
        return;
    end

    if recording_index > numel(all_images)
        return;
    end

    if isempty(all_images{recording_index})
        return;
    end

    images = ...
        all_images{recording_index};
end


%% ========================================================================
function img = get_plane_image_mean_overview( ...
    images, ...
    plane_index)

    img = [];

    if isempty(images)
        return;
    end

    if plane_index > numel(images)
        return;
    end

    img = ...
        images{plane_index};

    if isempty(img)
        img = [];
    end
end


%% ========================================================================
function [img1, img2] = match_mean_image_sizes( ...
    img1, ...
    img2)

    if isempty(img1) || ...
            isempty(img2)

        return;
    end

    h = ...
        min( ...
            size(img1,1), ...
            size(img2,1));

    w = ...
        min( ...
            size(img1,2), ...
            size(img2,2));

    img1 = ...
        img1(1:h, 1:w);

    img2 = ...
        img2(1:h, 1:w);
end


%% ========================================================================
function rgb = create_single_channel_rgb( ...
    img, ...
    channel)

    if isempty(img)

        rgb = ...
            zeros(10, 10, 3);

        return;
    end

    img = ...
        normalize_mean_image_contrast(img);

    rgb = ...
        zeros( ...
            size(img,1), ...
            size(img,2), ...
            3);

    rgb(:,:,channel) = ...
        img;
end


%% ========================================================================
function rgb = create_mean_image_overlay( ...
    gcamp, ...
    electroporated, ...
    electroporated_color_channel)

    [gcamp, electroporated] = ...
        match_mean_image_sizes( ...
            gcamp, ...
            electroporated);

    gcamp = ...
        normalize_mean_image_contrast( ...
            gcamp);

    electroporated = ...
        normalize_mean_image_contrast( ...
            electroporated);

    rgb = ...
        zeros( ...
            size(gcamp,1), ...
            size(gcamp,2), ...
            3);

    % GCaMP toujours vert
    rgb(:,:,2) = ...
        gcamp;

    % Electroporated rouge ou bleu
    rgb(:,:,electroporated_color_channel) = ...
        electroporated;
end


%% ========================================================================
function img = normalize_mean_image_contrast(img)

    img = ...
        double(img);

    p1 = ...
        calculate_percentile_mean_overview( ...
            img(:), ...
            1);

    p99 = ...
        calculate_percentile_mean_overview( ...
            img(:), ...
            99);


    if ~isfinite(p1)

        p1 = ...
            min(img(:));
    end


    if ~isfinite(p99)

        p99 = ...
            max(img(:));
    end


    if p99 <= p1

        img = ...
            zeros(size(img));

        return;
    end


    img = ...
        (img - p1) / ...
        (p99 - p1);

    img(img < 0) = 0;
    img(img > 1) = 1;
end


%% ========================================================================
function value = calculate_percentile_mean_overview( ...
    values, ...
    p)

    values = ...
        values(isfinite(values));

    if isempty(values)

        value = NaN;

        return;
    end


    values = ...
        sort(values(:));

    idx = ...
        1 + ...
        (numel(values) - 1) * ...
        p / 100;

    i1 = ...
        floor(idx);

    i2 = ...
        ceil(idx);


    if i1 == i2

        value = ...
            values(i1);

    else

        alpha = ...
            idx - i1;

        value = ...
            (1 - alpha) * values(i1) + ...
            alpha * values(i2);
    end
end


%% ========================================================================
function output_root_folder = get_root_folder_mean_overview( ...
    gcamp_root_folders, ...
    recording_index)

    output_root_folder = '';

    if isempty(gcamp_root_folders)
        return;
    end

    if recording_index > numel(gcamp_root_folders)
        return;
    end

    if isempty(gcamp_root_folders{recording_index})
        return;
    end

    output_root_folder = ...
        char( ...
            string( ...
                gcamp_root_folders{recording_index}));
end


%% ========================================================================
function date_name = get_date_name_mean_overview( ...
    current_dates, ...
    recording_index)

    date_name = ...
        'date_unknown';

    if isempty(current_dates)
        return;
    end


    if ischar(current_dates) || ...
            isstring(current_dates) || ...
            isnumeric(current_dates)

        date_name = ...
            normalize_text_mean_overview( ...
                current_dates);

        return;
    end


    if recording_index > numel(current_dates)
        return;
    end


    if isempty(current_dates{recording_index})
        return;
    end


    date_name = ...
        normalize_text_mean_overview( ...
            current_dates{recording_index});
end


%% ========================================================================
function age_name = get_age_name_mean_overview( ...
    current_ages, ...
    recording_index)

    age_name = ...
        'age_unknown';

    if isempty(current_ages)
        return;
    end


    if ischar(current_ages) || ...
            isstring(current_ages) || ...
            isnumeric(current_ages)

        age_name = ...
            normalize_text_mean_overview( ...
                current_ages);

        return;
    end


    if recording_index > numel(current_ages)
        return;
    end


    if isempty(current_ages{recording_index})
        return;
    end


    age_name = ...
        char( ...
            string( ...
                current_ages{recording_index}));
end


%% ========================================================================
function show_empty_mean_image_panel( ...
    ax, ...
    message)

    cla(ax);

    axis(ax, 'off');

    text( ...
        ax, ...
        0.5, ...
        0.5, ...
        message, ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'Color', [0.5 0.5 0.5], ...
        'FontSize', 11);
end


%% ========================================================================
function save_mean_overview_figure( ...
    fig, ...
    file_path)

    try

        exportgraphics( ...
            fig, ...
            file_path, ...
            'Resolution', 300);

    catch

        saveas( ...
            fig, ...
            file_path);
    end
end


%% ========================================================================
function value = normalize_text_mean_overview(value)

    if isempty(value)

        value = '';

        return;
    end


    if isstring(value)

        value = ...
            char(value);

    elseif iscell(value)

        value = ...
            char( ...
                string( ...
                    value{1}));

    elseif isnumeric(value)

        value = ...
            num2str(value);
    end


    value = ...
        strtrim(value);
end


%% ========================================================================
function value = sanitize_filename_mean_overview(value)

    value = ...
        normalize_text_mean_overview( ...
            value);

    value = ...
        regexprep( ...
            value, ...
            '[<>:"/\\|?*]', ...
            '-');

    value = ...
        regexprep( ...
            value, ...
            '\s+', ...
            '_');

    value = ...
        regexprep( ...
            value, ...
            '_+', ...
            '_');

    value = ...
        regexprep( ...
            value, ...
            '^[_\-.]+|[_\-.]+$', ...
            '');
end