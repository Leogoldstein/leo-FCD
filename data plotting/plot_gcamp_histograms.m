function plot_gcamp_histograms(results_analysis, gcamp_root_folders, current_animal_group, current_ages_group)

numFolders = length(results_analysis);

for m = 1:numFolders

    fig = [];
    try
        output_folder = gcamp_root_folders{m};

        if ~exist(output_folder, 'dir')
            mkdir(output_folder);
        end

        filename = fullfile(output_folder, sprintf( ...
            'GCaMP_freq_intervals_histograms_%s_%s.png', ...
            char(string(current_animal_group)), char(string(current_ages_group{m}))));

        if exist(filename, 'file')
            fprintf('Rec %d: figure déjà existante, skip: %s\n', m, filename);
            continue;
        end

        if isfield(results_analysis, 'FrequencyPerCell_gcamp')
            freq = results_analysis(m).FrequencyPerCell_gcamp;
        else
            freq = [];
        end

        if isfield(results_analysis, 'InterEventIntervals_gcamp_ms')
            intervals = results_analysis(m).InterEventIntervals_gcamp_ms / 1000; % ms -> s
        
        else
            intervals = [];
        end

        freq = force_numeric_vector(freq);
        intervals = force_numeric_vector(intervals);

        if isempty(freq) && isempty(intervals)
            fprintf('Rec %d: aucune donnée exploitable, skip.\n', m);
            continue;
        end

        fig = figure('Position', [100 100 1000 400]);
        tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

        nexttile;
        if ~isempty(freq)
            histogram(freq, 50);
            xlabel('Frequency (events / min)');
            ylabel('Count');
            title('GCaMP frequencies');
            grid on;
        else
            text(0.5, 0.5, 'No frequency data', 'HorizontalAlignment', 'center');
            axis off;
        end

        nexttile;
        if ~isempty(intervals)
        
            histogram(intervals, 150, 'BinLimits', [0 60]);
            xlim([0 60]);
        
            xlabel('Inter-event interval (s)');
            ylabel('Count');
            title('Inter-event intervals');
            grid on;
        else
            text(0.5, 0.5, 'No interval data', 'HorizontalAlignment', 'center');
            axis off;
        end

        title(tl, sprintf('GCaMP frequency and interval histograms - %s %s', ...
            char(string(current_animal_group)), char(string(current_ages_group{m}))));

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