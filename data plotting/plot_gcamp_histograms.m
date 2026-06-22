function plot_gcamp_histograms(results_analysis, gcamp_root_folders, current_animal_group, current_ages_group)

    numFolders = numel(gcamp_root_folders);

    for m = 1:numFolders

        fig = [];
        try
            output_folder = gcamp_root_folders{m};

            if ~exist(output_folder, 'dir')
                mkdir(output_folder);
            end

            filename = fullfile(output_folder, sprintf( ...
                'GCaMP_freq_intervals_histograms_by_plane_%s_%s.png', ...
                char(string(current_animal_group)), char(string(current_ages_group{m}))));

            if exist(filename, 'file')
                fprintf('Rec %d: figure déjà existante, skip: %s\n', m, filename);
                continue;
            end

            freq_by_plane = get_results_analysis_value( ...
                results_analysis, {'gcamp_plane', 'FrequencyPerCell'}, m);

            intervals_by_plane = get_results_analysis_value( ...
                results_analysis, {'gcamp_plane', 'InterEventIntervals_ms'}, m);

            if ~iscell(freq_by_plane)
                freq_by_plane = {freq_by_plane};
            end

            if ~iscell(intervals_by_plane)
                intervals_by_plane = {intervals_by_plane};
            end

            nPlanes = max(numel(freq_by_plane), numel(intervals_by_plane));

            if nPlanes == 0
                fprintf('Rec %d: aucune donnée exploitable, skip.\n', m);
                continue;
            end

            has_data = false;

            for p = 1:nPlanes

                freq_p = [];
                int_p  = [];

                if p <= numel(freq_by_plane)
                    freq_p = force_numeric_vector(freq_by_plane{p});
                end

                if p <= numel(intervals_by_plane)
                    int_p = force_numeric_vector(intervals_by_plane{p}) ./ 1000;
                end

                if ~isempty(freq_p) || ~isempty(int_p)
                    has_data = true;
                    break;
                end
            end

            if ~has_data
                fprintf('Rec %d: aucune donnée exploitable, skip.\n', m);
                continue;
            end

            fig = figure('Color','w', ...
                'Position', [100 100 1100 max(350, 300*nPlanes)], ...
                'Name', sprintf('GCaMP histograms by plane - %s %s', ...
                char(string(current_animal_group)), char(string(current_ages_group{m}))));

            tl = tiledlayout(nPlanes, 2, ...
                'TileSpacing', 'compact', ...
                'Padding', 'compact');

            for p = 1:nPlanes

                freq = [];
                intervals = [];

                if p <= numel(freq_by_plane)
                    freq = force_numeric_vector(freq_by_plane{p});
                end

                if p <= numel(intervals_by_plane)
                    intervals = force_numeric_vector(intervals_by_plane{p}) ./ 1000;
                end

                nexttile;
                if ~isempty(freq)
                    histogram(freq, 50);
                    xlabel('Frequency (events / min)');
                    ylabel('Count');
                    title(sprintf('Plane %d - GCaMP frequencies', p), 'Interpreter','none');
                    grid on;
                    box off;
                else
                    empty_hist_axis(sprintf('Plane %d - No frequency data', p));
                end

                nexttile;
                if ~isempty(intervals)
                    histogram(intervals, 150, 'BinLimits', [0 60]);
                    xlim([0 60]);
                    xlabel('Inter-event interval (s)');
                    ylabel('Count');
                    title(sprintf('Plane %d - Inter-event intervals', p), 'Interpreter','none');
                    grid on;
                    box off;
                else
                    empty_hist_axis(sprintf('Plane %d - No interval data', p));
                end
            end

            title(tl, sprintf('GCaMP frequency and interval histograms by plane - %s %s', ...
                char(string(current_animal_group)), ...
                char(string(current_ages_group{m}))), ...
                'Interpreter','none', ...
                'FontWeight','bold');

            saveas(fig, filename);
            close(fig);

            fprintf('Saved: %s\n', filename);

        catch ME
            fprintf('Erreur rec %d: %s\n', m, ME.message);
            if ~isempty(fig) && ishghandle(fig)
                close(fig);
            end
        end
    end
end


function val = get_results_analysis_value(results_analysis, path_fields, idx)

    val = [];

    if isempty(results_analysis) || ~isstruct(results_analysis)
        return;
    end

    current = results_analysis;

    for i = 1:numel(path_fields)

        fn = path_fields{i};

        if ~isstruct(current) || ~isfield(current, fn)
            return;
        end

        current = current.(fn);
    end

    if iscell(current)
        if numel(current) >= idx
            val = current{idx};
        end
    else
        val = current;
    end
end


function v = force_numeric_vector(x)

    if isempty(x)
        v = [];
        return;
    end

    if iscell(x)
        x = x(~cellfun(@isempty, x));

        if isempty(x)
            v = [];
            return;
        end

        x = x(cellfun(@isnumeric, x));

        if isempty(x)
            v = [];
            return;
        end

        x = cellfun(@(c) c(:), x, 'UniformOutput', false);
        x = vertcat(x{:});
    end

    if ~isnumeric(x)
        v = [];
        return;
    end

    v = x(:);
    v = v(isfinite(v));
end


function empty_hist_axis(msg)

    title(msg, 'Interpreter','none');
    xticks([]);
    yticks([]);
    box off;
end