function plot_gcamp_histograms( ...
    results_analysis, ...
    gcamp_root_folders, ...
    current_animal_group, ...
    current_ages_group)

    numFolders = ...
        numel(gcamp_root_folders);


    %==============================================================%
    % Boucle recordings
    %==============================================================%
    for m = 1:numFolders

        fig = [];

        try

            %======================================================%
            % Output folder
            %======================================================%
            output_folder = ...
                gcamp_root_folders{m};

            if isempty(output_folder)
                continue;
            end

            if exist(output_folder, 'dir') ~= 7
                mkdir(output_folder);
            end


            %======================================================%
            % Age
            %======================================================%
            current_age = '';

            if ~isempty(current_ages_group)

                if iscell(current_ages_group)

                    if numel(current_ages_group) >= m
                        current_age = ...
                            char(string(current_ages_group{m}));
                    end

                elseif numel(current_ages_group) >= m

                    current_age = ...
                        char(string(current_ages_group(m)));

                else

                    current_age = ...
                        char(string(current_ages_group));
                end
            end


            %======================================================%
            % Nom du fichier
            %======================================================%
            filename = ...
                fullfile( ...
                    output_folder, ...
                    sprintf( ...
                        'GCaMP_freq_intervals_histograms_by_plane_%s_%s.png', ...
                        char(string(current_animal_group)), ...
                        current_age));


            %======================================================%
            % Skip si déjà existant
            %======================================================%
            if exist(filename, 'file') == 2

                fprintf( ...
                    'Rec %d: figure déjà existante, skip: %s\n', ...
                    m, ...
                    filename);

                continue;
            end


            %======================================================%
            % Nouvelle structure results_analysis
            %======================================================%
            freq_by_plane = ...
                get_results_analysis_value( ...
                    results_analysis, ...
                    { ...
                        'gcamp_plane', ...
                        'activity', ...
                        'FrequencyPerCell' ...
                    }, ...
                    m);


            intervals_by_plane = ...
                get_results_analysis_value( ...
                    results_analysis, ...
                    { ...
                        'gcamp_plane', ...
                        'activity', ...
                        'InterEventIntervals_ms' ...
                    }, ...
                    m);


            %======================================================%
            % Normaliser en cell par plan
            %======================================================%
            if ~iscell(freq_by_plane)

                if isempty(freq_by_plane)
                    freq_by_plane = {};
                else
                    freq_by_plane = {freq_by_plane};
                end
            end


            if ~iscell(intervals_by_plane)

                if isempty(intervals_by_plane)
                    intervals_by_plane = {};
                else
                    intervals_by_plane = {intervals_by_plane};
                end
            end


            nPlanes = ...
                max( ...
                    numel(freq_by_plane), ...
                    numel(intervals_by_plane));


            if nPlanes == 0

                fprintf( ...
                    'Rec %d: aucune donnée exploitable, skip.\n', ...
                    m);

                continue;
            end


            %======================================================%
            % Vérifier qu'il existe au moins une donnée
            %======================================================%
            has_data = ...
                false;


            for p = 1:nPlanes

                freq_p = [];
                int_p = [];


                if p <= numel(freq_by_plane)

                    freq_p = ...
                        force_numeric_vector( ...
                            freq_by_plane{p});
                end


                if p <= numel(intervals_by_plane)

                    int_p = ...
                        force_numeric_vector( ...
                            intervals_by_plane{p});

                    int_p = ...
                        int_p ./ 1000;
                end


                if ~isempty(freq_p) || ...
                        ~isempty(int_p)

                    has_data = ...
                        true;

                    break;
                end
            end


            if ~has_data

                fprintf( ...
                    'Rec %d: aucune donnée exploitable, skip.\n', ...
                    m);

                continue;
            end


            %======================================================%
            % Figure
            %======================================================%
            fig = ...
                figure( ...
                    'Color', 'w', ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.05 0.90 0.88], ...
                    'Name', ...
                    sprintf( ...
                        'GCaMP histograms by plane - %s %s', ...
                        char(string(current_animal_group)), ...
                        current_age));


            tl = ...
                tiledlayout( ...
                    fig, ...
                    nPlanes, ...
                    2, ...
                    'TileSpacing', 'compact', ...
                    'Padding', 'compact');


            %======================================================%
            % Boucle plans
            %======================================================%
            for p = 1:nPlanes

                plane_number = ...
                    p - 1;

                freq = [];
                intervals = [];


                %--------------------------------------------------%
                % Frequency
                %--------------------------------------------------%
                if p <= numel(freq_by_plane)

                    freq = ...
                        force_numeric_vector( ...
                            freq_by_plane{p});
                end


                %--------------------------------------------------%
                % Inter-event intervals
                % ms -> sec
                %--------------------------------------------------%
                if p <= numel(intervals_by_plane)

                    intervals = ...
                        force_numeric_vector( ...
                            intervals_by_plane{p});

                    intervals = ...
                        intervals ./ 1000;
                end


                %==================================================%
                % Histogramme fréquence
                %==================================================%
                ax1 = ...
                    nexttile(tl);

                if ~isempty(freq)

                    histogram( ...
                        ax1, ...
                        freq, ...
                        50);


                    xlabel( ...
                        ax1, ...
                        'Frequency (events / min)');


                    ylabel( ...
                        ax1, ...
                        'Count');


                    title( ...
                        ax1, ...
                        sprintf( ...
                            'Plane %d - GCaMP frequencies', ...
                            plane_number), ...
                        'Interpreter', 'none');


                    grid( ...
                        ax1, ...
                        'on');

                    box( ...
                        ax1, ...
                        'off');

                else

                    empty_hist_axis( ...
                        ax1, ...
                        sprintf( ...
                            'Plane %d - No frequency data', ...
                            plane_number));
                end


                %==================================================%
                % Histogramme IEI
                %==================================================%
                ax2 = ...
                    nexttile(tl);

                if ~isempty(intervals)

                    histogram( ...
                        ax2, ...
                        intervals, ...
                        150, ...
                        'BinLimits', [0 60]);


                    xlim( ...
                        ax2, ...
                        [0 60]);


                    xlabel( ...
                        ax2, ...
                        'Inter-event interval (s)');


                    ylabel( ...
                        ax2, ...
                        'Count');


                    title( ...
                        ax2, ...
                        sprintf( ...
                            'Plane %d - Inter-event intervals', ...
                            plane_number), ...
                        'Interpreter', 'none');


                    grid( ...
                        ax2, ...
                        'on');

                    box( ...
                        ax2, ...
                        'off');

                else

                    empty_hist_axis( ...
                        ax2, ...
                        sprintf( ...
                            'Plane %d - No interval data', ...
                            plane_number));
                end
            end


            %======================================================%
            % Titre général
            %======================================================%
            title( ...
                tl, ...
                sprintf( ...
                    ['GCaMP frequency and interval histograms ' ...
                     'by plane - %s %s'], ...
                    char(string(current_animal_group)), ...
                    current_age), ...
                'Interpreter', 'none', ...
                'FontWeight', 'bold');


            %======================================================%
            % Sauvegarde
            %======================================================%
            exportgraphics( ...
                fig, ...
                filename, ...
                'Resolution', 300);


            fprintf( ...
                'Saved: %s\n', ...
                filename);


            %======================================================%
            % Fermeture
            %======================================================%
            if ~isempty(fig) && ...
                    ishghandle(fig)

                close(fig);
            end


        catch ME

            fprintf( ...
                'Erreur rec %d: %s\n', ...
                m, ...
                ME.message);


            if ~isempty(fig) && ...
                    ishghandle(fig)

                close(fig);
            end
        end
    end
end


function val = get_results_analysis_value( ...
    results_analysis, ...
    path_fields, ...
    idx)

    val = [];


    if isempty(results_analysis) || ...
            ~isstruct(results_analysis)

        return;
    end


    current = ...
        results_analysis;


    for i = 1:numel(path_fields)

        field_name = ...
            path_fields{i};


        if ~isstruct(current) || ...
                ~isfield(current, field_name)

            return;
        end


        current = ...
            current.(field_name);
    end


    if iscell(current)

        if numel(current) >= idx

            val = ...
                current{idx};
        end

    else

        val = ...
            current;
    end
end


function v = force_numeric_vector(x)

    if isempty(x)

        v = [];
        return;
    end


    %==============================================================%
    % Cell array
    %==============================================================%
    if iscell(x)

        x = ...
            x(~cellfun(@isempty, x));


        if isempty(x)

            v = [];
            return;
        end


        is_numeric = ...
            cellfun( ...
                @(c) isnumeric(c) || islogical(c), ...
                x);


        x = ...
            x(is_numeric);


        if isempty(x)

            v = [];
            return;
        end


        x = ...
            cellfun( ...
                @(c) double(c(:)), ...
                x, ...
                'UniformOutput', false);


        x = ...
            vertcat(x{:});
    end


    %==============================================================%
    % Numeric
    %==============================================================%
    if ~(isnumeric(x) || islogical(x))

        v = [];
        return;
    end


    v = ...
        double(x(:));


    v = ...
        v(isfinite(v));
end


function empty_hist_axis( ...
    ax, ...
    msg)

    title( ...
        ax, ...
        msg, ...
        'Interpreter', 'none');


    xticks( ...
        ax, ...
        []);


    yticks( ...
        ax, ...
        []);


    box( ...
        ax, ...
        'off');
end