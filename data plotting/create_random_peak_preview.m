function create_random_peak_preview( ...
        valid_cells, ...
        DF, ...
        Acttmp2, ...
        thresholds, ...
        gcamp_output_folder, ...
        automatic_selection, ...
        output_folder, ...
        line_name, ...
        animal_name, ...
        date_name, ...
        age_name, ...
        plane_number)
%CREATE_RANDOM_PEAK_PREVIEW
%
% Crée une figure avec jusqu'à 10 cellules tirées au hasard parmi
% les cellules gardées et affiche leurs traces avec les pics détectés.
%
% Nomenclature :
%
%   line_animal_date_age_plane_nomFigure.png
%
% Exemple :
%
%   FCD_mtor41_2024-06-28_P10_plane0_random_peak_preview.png
%
% Si line_name est vide :
%
%   mtor41_2024-06-28_P10_plane0_random_peak_preview.png
%
% La même nomenclature est utilisée dans :
%
%   1) gcamp_output_folder
%   2) output_folder

    % =========================================================
    % Arguments facultatifs
    % =========================================================
    if nargin < 4 || isempty(thresholds)
        thresholds = [];
    end

    if nargin < 5 || isempty(gcamp_output_folder)
        gcamp_output_folder = '';
    end

    if nargin < 6 || isempty(automatic_selection)
        automatic_selection = 0;
    end

    if nargin < 7 || isempty(output_folder)
        output_folder = '';
    end

    if nargin < 8 || isempty(line_name)
        line_name = '';
    end

    if nargin < 9 || isempty(animal_name)
        animal_name = '';
    end

    if nargin < 10 || isempty(date_name)
        date_name = '';
    end

    if nargin < 11 || isempty(age_name)
        age_name = '';
    end

    if nargin < 12 || isempty(plane_number)
        plane_number = [];
    end

    % =========================================================
    % Normalisation des chemins
    % =========================================================
    gcamp_output_folder = normalize_text_value( ...
        gcamp_output_folder);

    output_folder = normalize_text_value( ...
        output_folder);

    % =========================================================
    % Normalisation des éléments du nom
    % =========================================================
    line_name = sanitize_filename_component( ...
        line_name);

    animal_name = sanitize_filename_component( ...
        animal_name);

    date_name = sanitize_filename_component( ...
        date_name);

    age_name = sanitize_filename_component( ...
        age_name);

    % =========================================================
    % Plan
    % =========================================================
    plane_name = '';

    if ~isempty(plane_number)

        if isnumeric(plane_number)

            plane_number = double(plane_number(1));

            if isfinite(plane_number)

                plane_name = sprintf( ...
                    'plane%d', ...
                    round(plane_number));
            end

        else

            plane_name = sanitize_filename_component( ...
                plane_number);

            if ~isempty(plane_name) && ...
                    ~startsWith( ...
                        lower(plane_name), ...
                        'plane')

                plane_name = [ ...
                    'plane', ...
                    plane_name];
            end
        end
    end

    % =========================================================
    % Vérification des données
    % =========================================================
    if isempty(valid_cells) || isempty(DF)

        warning( ...
            'Aucune cellule valide à afficher dans la preview.');

        return;
    end

    nCellsFinal = size(DF, 1);

    if nCellsFinal == 0

        warning( ...
            'DF final vide, preview non générée.');

        return;
    end

    if size(DF, 2) == 0

        warning( ...
            'Les traces DF ne contiennent aucune frame.');

        return;
    end

    % =========================================================
    % Construction du nom de figure
    %
    % line_animal_date_age_plane_nomFigure
    % =========================================================
    name_parts = { ...
        line_name, ...
        animal_name, ...
        date_name, ...
        age_name, ...
        plane_name};

    % Supprime automatiquement les éléments vides.
    % Donc aucun "_" initial si line_name est vide.
    name_parts = name_parts( ...
        ~cellfun(@isempty, name_parts));

    if isempty(name_parts)

        figure_base_name = ...
            'random_peak_preview';

    else

        figure_base_name = [ ...
            strjoin(name_parts, '_'), ...
            '_random_peak_preview'];

    end

    % =========================================================
    % Première destination :
    % gcamp_output_folder
    % =========================================================
    local_png_path = '';
    
    if ~isempty(gcamp_output_folder)
    
        if exist(gcamp_output_folder, 'dir') ~= 7
            mkdir(gcamp_output_folder);
        end
    
        local_png_path = fullfile( ...
            gcamp_output_folder, ...
            [figure_base_name '.png']);
    end
    
    % =========================================================
    % Deuxième destination :
    % output_folder\Development ou output_folder\Adult
    % =========================================================
    summary_png_path = '';
    
    if ~isempty(output_folder)
    
        % -----------------------------------------------------
        % Récupérer l'âge numérique depuis age_name
        % Exemples :
        %   'P10' -> 10
        %   'P15' -> 15
        %   'P30' -> 30
        % -----------------------------------------------------
        current_age_value = str2double( ...
            regexprep( ...
                char(string(age_name)), ...
                '[^\d\.]', ...
                ''));
    
        % -----------------------------------------------------
        % Choisir le dossier selon l'âge
        % -----------------------------------------------------
        if isfinite(current_age_value) && ...
                current_age_value <= 15
    
            current_summary_folder = fullfile( ...
                output_folder, ...
                'Development');
    
        else
    
            current_summary_folder = fullfile( ...
                output_folder, ...
                'Adult');
        end
    
        % -----------------------------------------------------
        % Créer le dossier si nécessaire
        % -----------------------------------------------------
        if exist(current_summary_folder, 'dir') ~= 7
            mkdir(current_summary_folder);
        end
    
        % -----------------------------------------------------
        % Chemin de sauvegarde
        % -----------------------------------------------------
        summary_png_path = fullfile( ...
            current_summary_folder, ...
            [figure_base_name '.png']);
    end

    % =========================================================
    % Vérifier si les fichiers existent déjà
    % =========================================================
    local_exists = ...
        ~isempty(local_png_path) && ...
        exist(local_png_path, 'file') == 2;

    summary_exists = ...
        ~isempty(summary_png_path) && ...
        exist(summary_png_path, 'file') == 2;

    % Si toutes les destinations disponibles existent déjà,
    % inutile de créer la figure.
    local_done = ...
        isempty(local_png_path) || ...
        local_exists;

    summary_done = ...
        isempty(summary_png_path) || ...
        summary_exists;

    if local_done && summary_done

        fprintf( ...
            ['Random peak preview already exists in all ' ...
             'required locations, skipped:\n%s\n'], ...
            figure_base_name);

        return;
    end

    % =========================================================
    % Tirage aléatoire
    % =========================================================
    nShow = min(10, nCellsFinal);

    rng('shuffle');

    idx_show = randperm( ...
        nCellsFinal, ...
        nShow);

    % =========================================================
    % Création de la figure
    % =========================================================
    figPrev = figure( ...
        'Name', figure_base_name, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Position', [150 80 1200 900], ...
        'Visible', 'on');

    nColumns = 2;
    nRows = ceil(nShow / nColumns);

    tiledlayout( ...
        figPrev, ...
        nRows, ...
        nColumns, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    % =========================================================
    % Affichage des cellules
    % =========================================================
    for k = 1:nShow

        ii = idx_show(k);

        if ii <= numel(valid_cells) && ...
                isfinite(valid_cells(ii))

            cid_orig = valid_cells(ii);

        else

            cid_orig = ii;
        end

        x = DF(ii, :);
        t = 1:numel(x);

        ax = nexttile;

        hold(ax, 'on');
        box(ax, 'off');

        set( ...
            ax, ...
            'LineWidth', 0.8, ...
            'TickDir', 'out');

        plot( ...
            ax, ...
            t, ...
            x, ...
            'k-', ...
            'LineWidth', 1);

        % -----------------------------------------------------
        % Pics détectés
        % -----------------------------------------------------
        pk = [];

        if iscell(Acttmp2) && ...
                numel(Acttmp2) >= ii && ...
                ~isempty(Acttmp2{ii})

            pk = Acttmp2{ii};
            pk = round(pk(:)');

            pk = pk( ...
                isfinite(pk) & ...
                pk >= 1 & ...
                pk <= numel(x));

            pk = unique(pk);
        end

        if ~isempty(pk)

            plot( ...
                ax, ...
                pk, ...
                x(pk), ...
                '*', ...
                'Color', [0.85 0.1 0.1], ...
                'MarkerSize', 3.5, ...
                'LineWidth', 0.7);
        end

        % -----------------------------------------------------
        % Seuil de détection
        % -----------------------------------------------------
        current_threshold = get_cell_threshold( ...
            thresholds, ...
            ii);

        if isfinite(current_threshold)

            yline( ...
                ax, ...
                current_threshold, ...
                '--', ...
                'LineWidth', 1);
        end

        title( ...
            ax, ...
            sprintf( ...
                'Cellule orig %g | final %d | n=%d pics', ...
                cid_orig, ...
                ii, ...
                numel(pk)), ...
            'FontWeight', 'bold', ...
            'Interpreter', 'none');

        xlabel(ax, 'Frames');
        ylabel(ax, '\DeltaF/F');

        xlim( ...
            ax, ...
            [1 max(1, numel(x))]);

        hold(ax, 'off');
    end

    % =========================================================
    % Sauvegarde dans gcamp_output_folder
    % uniquement si le fichier n'existe pas
    % =========================================================
    if ~isempty(local_png_path) && ...
            ~local_exists

        save_preview_figure( ...
            figPrev, ...
            local_png_path);

        fprintf( ...
            ['Preview PNG sauvegardée dans le dossier ' ...
             'de traitement :\n%s\n'], ...
            local_png_path);
    end

    % =========================================================
    % Sauvegarde dans output_folder
    % uniquement si nécessaire
    % =========================================================
    if ~isempty(summary_png_path) && ...
            ~summary_exists && ...
            automatic_selection

        same_destination = ...
            ~isempty(local_png_path) && ...
            strcmpi( ...
                char(local_png_path), ...
                char(summary_png_path));

        if ~same_destination

            save_preview_figure( ...
                figPrev, ...
                summary_png_path);

            fprintf( ...
                ['Copie de la preview sauvegardée dans ' ...
                 'output_folder :\n%s\n'], ...
                summary_png_path);

        elseif ~local_exists

            fprintf( ...
                ['Local path and output path are identical; ' ...
                 'single save performed:\n%s\n'], ...
                summary_png_path);
        end
    end

    % =========================================================
    % Fermeture
    % =========================================================
    if ishghandle(figPrev)
        close(figPrev);
    end
end


function current_threshold = get_cell_threshold( ...
        thresholds, ...
        cell_index)
%GET_CELL_THRESHOLD Extrait le seuil correspondant à une cellule.

    current_threshold = NaN;

    if isempty(thresholds)
        return;
    end

    if iscell(thresholds)

        if numel(thresholds) < cell_index || ...
                isempty(thresholds{cell_index})
            return;
        end

        value = thresholds{cell_index};

    else

        if numel(thresholds) < cell_index
            return;
        end

        value = thresholds(cell_index);
    end

    if isnumeric(value) && ...
            isscalar(value) && ...
            isfinite(value)

        current_threshold = double(value);
    end
end


function save_preview_figure( ...
        fig_handle, ...
        file_path)
%SAVE_PREVIEW_FIGURE Sauvegarde robuste de la figure.

    try

        exportgraphics( ...
            fig_handle, ...
            file_path, ...
            'Resolution', 200);

    catch ME_export

        try

            saveas( ...
                fig_handle, ...
                file_path);

        catch ME_saveas

            warning( ...
                ['Impossible de sauvegarder la preview :\n%s\n' ...
                 'Erreur exportgraphics : %s\n' ...
                 'Erreur saveas : %s'], ...
                file_path, ...
                ME_export.message, ...
                ME_saveas.message);
        end
    end
end


function value = normalize_text_value(value)
%NORMALIZE_TEXT_VALUE Convertit une valeur textuelle en char.

    if isempty(value)

        value = '';

        return;
    end

    if isstring(value)

        value = char(value(1));

    elseif iscell(value)

        value = value{1};

        if isstring(value)
            value = char(value);
        end
    end

    if isnumeric(value)
        value = num2str(value);
    end

    if ~ischar(value)
        value = char(string(value));
    end

    value = strtrim(value);
end


function value = sanitize_filename_component(value)
%SANITIZE_FILENAME_COMPONENT Retire les caractères interdits.

    value = normalize_text_value(value);

    if isempty(value)
        return;
    end

    value = regexprep( ...
        value, ...
        '[<>:"/\\|?*]', ...
        '-');

    value = regexprep( ...
        value, ...
        '\s+', ...
        '_');

    value = regexprep( ...
        value, ...
        '_+', ...
        '_');

    value = regexprep( ...
        value, ...
        '^[_\-.]+|[_\-.]+$', ...
        '');
end