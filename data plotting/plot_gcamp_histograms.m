function plot_gcamp_histograms(results_analysis, gcamp_root_folders, current_animal_group, current_ages_group)

numFolders = length(results_analysis);

for m = 1:numFolders

    fig = [];
    try
        % -----------------------------
        % Nom dossier / fichier
        % -----------------------------
        output_folder = gcamp_root_folders{m};

        if ~exist(output_folder, 'dir')
            mkdir(output_folder);
        end

        filename = fullfile(output_folder, sprintf( ...
            'GCaMP_histograms_%s_%s.png', ...
            char(string(current_animal_group)), char(string(current_ages_group{m}))));

        % -----------------------------
        % Si la figure existe déjà, skip
        % -----------------------------
        if exist(filename, 'file')
            fprintf('Rec %d: figure déjà existante, skip: %s\n', m, filename);
            continue;
        end

        % -----------------------------
        % Récupération des données
        % -----------------------------
        dur = results_analysis(m).AllDurations_gcamp;
        amp = results_analysis(m).AllAmplitudes_gcamp;
        freq = results_analysis(m).FrequencyPerCell_gcamp;

        % -----------------------------
        % Conversion robuste en vecteurs numériques
        % -----------------------------
        dur  = force_numeric_vector(dur);
        amp  = force_numeric_vector(amp);
        freq = force_numeric_vector(freq);

        if isempty(dur) && isempty(amp) && isempty(freq)
            fprintf('Rec %d: aucune donnée exploitable, skip.\n', m);
            continue;
        end

        % -----------------------------
        % Figure
        % -----------------------------
        fig = figure('Position', [100 100 1400 400]);
        tl = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

        % Histogramme durées
        nexttile;
        if ~isempty(dur)
            histogram(dur, 50);
            xlabel('Duration');
            ylabel('Count');
            title('GCaMP durations');
            grid on;
        else
            text(0.5, 0.5, 'No duration data', 'HorizontalAlignment', 'center');
            axis off;
        end

        % Histogramme amplitudes
        nexttile;
        if ~isempty(amp)
            histogram(amp, 50);
            xlabel('Amplitude');
            ylabel('Count');
            title('GCaMP amplitudes');
            grid on;
        else
            text(0.5, 0.5, 'No amplitude data', 'HorizontalAlignment', 'center');
            axis off;
        end

        % Histogramme fréquences
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

        title(tl, sprintf('GCaMP histograms - %s %s', ...
            char(string(current_animal_group)), char(string(current_ages_group{m}))));

        % -----------------------------
        % Sauvegarde
        % -----------------------------
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
        % garder seulement les cellules non vides
        x = x(~cellfun(@isempty, x));

        if isempty(x)
            v = [];
            return;
        end

        % garder seulement les cellules numériques
        x = x(cellfun(@isnumeric, x));

        if isempty(x)
            v = [];
            return;
        end

        % transformer chaque cellule en vecteur colonne
        x = cellfun(@(c) c(:), x, 'UniformOutput', false);

        % concaténer
        x = vertcat(x{:});
    end

    if ~isnumeric(x)
        v = [];
        return;
    end

    v = x(:);
    v = v(isfinite(v));
end