function [matched_gcamp_idx, matched_cellpose_idx_all, is_cell_blue] = show_masks_and_overlaps( ...
    iscell_gcamp, gcamp_props, gcamp_props_false, cellpose_props, meanImg, aligned_image, ... 
    outline_gcampx, outline_gcampy, outline_gcampx_false, outline_gcampy_false, ...
    outline_x_cellpose, outline_y_cellpose, R, gcamp_output_folder)

try
    % ---------- Extraire les centroids avec une fonction robuste ----------
    gcamp_centroids       = get_centroids(gcamp_props);        % N_true x 2
    gcamp_false_centroids = get_centroids(gcamp_props_false);  % N_false x 2
    cellpose_centroids    = get_centroids(cellpose_props);     % N_cp x 2

    % Vérifier s'il y a des données exploitables
    if isempty(cellpose_centroids) || (isempty(gcamp_centroids) && isempty(gcamp_false_centroids))
        fprintf('Skipping group: No centroids to match.\n');
        matched_gcamp_idx        = [];
        matched_cellpose_idx_all = [];
        is_cell_blue             = [];
        return;
    end


    % ---------- Fusionner toutes les cellules GCaMP (vraies + fausses) ----------
    all_gcamp_centroids = [gcamp_centroids; gcamp_false_centroids];
    n_true  = size(gcamp_centroids, 1);
    % n_false = size(gcamp_false_centroids, 1);

    % Calculer les distances entre chaque pair de centroids
    D = pdist2(all_gcamp_centroids, cellpose_centroids);

    % Trouver les centroids qui se chevauchent dans le rayon R
    [matched_all_gcamp_idx, matched_cellpose_idx_all] = find(D < R);

    % ---------- Séparer vrais / faux GCaMP ----------
    is_true_match     = matched_all_gcamp_idx <= n_true;
    matched_gcamp_idx = matched_all_gcamp_idx(is_true_match);

    % ---------- Cellpose avec / sans correspondance ----------
    all_cellpose_indices    = (1:size(cellpose_centroids, 1))';
    matched_cellpose_unique = unique(matched_cellpose_idx_all);
    unmatched_cellpose_idx  = setdiff(all_cellpose_indices, matched_cellpose_unique);

    fprintf('Matching: %d vrais GCaMP appariés à %d Cellpose (tous types).\n', ...
        numel(matched_gcamp_idx), numel(matched_cellpose_unique));

    % ---------- IoU approx ----------
    intersection = numel(matched_cellpose_unique);
    total_gcamp  = size(all_gcamp_centroids, 1);
    total_cp     = size(cellpose_centroids, 1);
    union_val    = total_gcamp + total_cp - intersection;
    IoU          = intersection / union_val;

    % ==================== AFFICHAGE ====================
    figure('Position', [100, 100, 1200, 800]);

    % --- Subplot 1: GCaMP sur meanImg ---
    subplot(1, 2, 1); hold on;
    imagesc(meanImg); colormap gray; axis image;

    % GCaMP vrais (vert)
    for ncell = 1:numel(outline_gcampx)
        if ~isempty(outline_gcampx{ncell})
            plot(outline_gcampx{ncell}, outline_gcampy{ncell}, '-', ...
                 'LineWidth', 0.5, 'Color', [0 1 0]);
        end
    end

    % GCaMP faux (orange)
    % for ncell = 1:numel(outline_gcampx_false)
    %     if ~isempty(outline_gcampx_false{ncell})
    %         plot(outline_gcampx_false{ncell}, outline_gcampy_false{ncell}, '-', ...
    %              'LineWidth', 0.5, 'Color', [1 0.5 0]);
    %     end
    % end

    % Croix Cellpose (match / no match)
    if ~isempty(matched_cellpose_unique)
        plot(cellpose_centroids(matched_cellpose_unique,1), ...
             cellpose_centroids(matched_cellpose_unique,2), ...
             'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [0 1 0]); % vert = match
    end
    if ~isempty(unmatched_cellpose_idx)
        plot(cellpose_centroids(unmatched_cellpose_idx,1), ...
             cellpose_centroids(unmatched_cellpose_idx,2), ...
             'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [1 0 0]); % rouge = no match
    end

    title('GCaMP (vert = vrai, orange = faux, croix vertes = match Cellpose, rouges = sans match)');
    xlabel('X'); ylabel('Y'); set(gca, 'YDir', 'reverse'); hold off;

    % --- Subplot 2: Cellpose sur aligned_image ---
    subplot(1, 2, 2); hold on;
    imagesc(aligned_image); colormap gray; axis image;

    % Outlines Cellpose (bleu)
    for ncell = 1:numel(outline_x_cellpose)
        if ~isempty(outline_x_cellpose{ncell})
            plot(outline_x_cellpose{ncell}, outline_y_cellpose{ncell}, '-', ...
                 'LineWidth', 0.5, 'Color', [0 0 1]);
        end
    end

    % Croix verte = match
    if ~isempty(matched_cellpose_unique)
        plot(cellpose_centroids(matched_cellpose_unique,1), ...
             cellpose_centroids(matched_cellpose_unique,2), ...
             'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [0 1 0]);
    end

    % Croix rouge = pas de match
    if ~isempty(unmatched_cellpose_idx)
        plot(cellpose_centroids(unmatched_cellpose_idx,1), ...
             cellpose_centroids(unmatched_cellpose_idx,2), ...
             'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [1 0 0]);
    end

    title(sprintf('Cellpose sur aligned\\_image (IoU: %.4f)', IoU));
    xlabel('X'); ylabel('Y'); set(gca, 'YDir', 'reverse'); hold off;
    drawnow;

    % ---- Sauvegarde figure ----
    fig_name = sprintf('GCaMP_vs_Cellpose_group');
    save_path = fullfile(gcamp_output_folder, [fig_name, '.png']);
    saveas(gcf, save_path);
    %uiwait(gcf);

    % ==================== is_cell_blue ====================
    is_cell_blue = nan(size(cellpose_props, 1), 1);  % NaN par défaut

    for i = 1:numel(matched_cellpose_idx_all)
        gcamp_idx    = matched_all_gcamp_idx(i);    % index dans all_gcamp_centroids
        cellpose_idx = matched_cellpose_idx_all(i); % index Cellpose

        if gcamp_idx <= numel(iscell_gcamp)
            % Vraie cellule GCaMP (selon iscell_gcamp)
            is_cell_blue(cellpose_idx) = iscell_gcamp(gcamp_idx);
        else
            % Faux positif GCaMP
            is_cell_blue(cellpose_idx) = NaN;  % ou 0 si tu préfères
        end
    end

catch ME
    fprintf('Erreur dans le groupe: %s\n', ME.message);
    matched_gcamp_idx        = [];
    matched_cellpose_idx_all = [];
    is_cell_blue             = [];
end
end

function centroids = get_centroids(props)
    % Retourne un [N x 2] de centroids, compatible avec :
    %  - struct array  (props(k).Centroid)
    %  - cell array de structs (props{k}.Centroid)
    %  - double N×2 (déjà centroids)
    %  - vide

    if isempty(props)
        centroids = [];
        return;
    end

    if isstruct(props)
        % struct array : props(k).Centroid
        centroids = cat(1, props.Centroid);

    elseif iscell(props)
        % cell array : props{k}.Centroid
        tmp = cellfun(@(s) s.Centroid, props, 'UniformOutput', false);
        centroids = cat(1, tmp{:});

    elseif isnumeric(props)
        % Déjà un tableau de centroids ?
        if size(props,2) == 2
            centroids = double(props);
        else
            error('get_centroids : numeric props mais taille inattendue [%d x %d]', ...
                  size(props,1), size(props,2));
        end

    else
        error('Type de props non supporté dans get_centroids (class = %s)', class(props));
    end
end
