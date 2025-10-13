function [matched_gcamp_idx, matched_cellpose_idx_all, is_cell_blue] = show_masks_and_overlaps( ...
    iscell_gcamp, gcamp_props, gcamp_props_false, cellpose_props, meanImg, aligned_image, ... 
    outline_gcampx, outline_gcampy, outline_gcampx_false, outline_gcampy_false, ...
    outline_x_cellpose, outline_y_cellpose, R, m, gcamp_output_folders)

try
    % --- Extraire les centroids ---
    gcamp_centroids       = cat(1, gcamp_props.Centroid);        % Nx2 (vraies cellules)
    gcamp_false_centroids = cat(1, gcamp_props_false.Centroid);  % Kx2 (fausses cellules)
    cellpose_centroids    = cat(1, cellpose_props.Centroid);     % Mx2

    % Vérifier s'il y a des données exploitables
    if isempty(cellpose_centroids) || (isempty(gcamp_centroids) && isempty(gcamp_false_centroids))
        fprintf('Skipping group %d: No centroids to match.\n', m);
        matched_gcamp_idx = [];
        matched_cellpose_idx_all = [];
        return;
    end

    % --- Fusionner toutes les cellules GCaMP (vraies + fausses) ---
    all_gcamp_centroids = [gcamp_centroids; gcamp_false_centroids];
    
    % Calculer les distances entre chaque pair de centroids
    D = pdist2(all_gcamp_centroids, cellpose_centroids);
    
    % Trouver les centroids qui se chevauchent dans le rayon R
    [matched_all_gcamp_idx, matched_cellpose_idx_all] = find(D < R);
    
    % --- Séparer vrais / faux GCaMP ---
    n_true = size(gcamp_centroids, 1);

    % Garde tous les Cellpose correspondants (true OR false)
    % mais filtre côté GCaMP pour ne garder que les vrais
    is_true_match = matched_all_gcamp_idx <= n_true;
    matched_gcamp_idx = matched_all_gcamp_idx(is_true_match);
    % matched_cellpose_idx_all : on garde tel quel (tous les appariements)

    % --- Déterminer les Cellpose sans correspondance ---
    all_cellpose_indices = 1:size(cellpose_centroids, 1);
    matched_cellpose_unique = unique(matched_cellpose_idx_all);
    unmatched_cellpose_idx = setdiff(all_cellpose_indices, matched_cellpose_unique);

    fprintf('Group %d: %d vrais GCaMP appariés à %d Cellpose (tous types, IoU approx.).\n', ...
        m, numel(matched_gcamp_idx), numel(matched_cellpose_unique));

    % ---- Calcul de IoU (approximation centroid-based) ----
    intersection = length(matched_cellpose_unique);
    total_gcamp = size(all_gcamp_centroids, 1);
    total_cellpose = size(cellpose_centroids, 1);
    union_val = total_gcamp + total_cellpose - intersection;
    IoU = intersection / union_val;

    % ---- AFFICHAGE ----
    figure('Position', [100, 100, 1200, 800]);

    % --- Subplot 1: GCaMP sur meanImg ---
    subplot(1, 2, 1);
    hold on;
    imagesc(meanImg); colormap gray; axis image;

    % --- GCaMP vrais (vert) ---
    for ncell = 1:length(outline_gcampx)
        if ~isempty(outline_gcampx{ncell})
            plot(outline_gcampx{ncell}, outline_gcampy{ncell}, '-', 'LineWidth', 0.5, 'Color', [0 1 0]);
        end
    end

    % --- GCaMP faux (orange) ---
    for ncell = 1:length(outline_gcampx_false)
        if ~isempty(outline_gcampx_false{ncell})
            plot(outline_gcampx_false{ncell}, outline_gcampy_false{ncell}, '-', 'LineWidth', 0.5, 'Color', [1 0.5 0]);
        end
    end

    % --- Ajouter les croix Cellpose (match et no-match) ---
    if ~isempty(matched_cellpose_unique)
        plot(cellpose_centroids(matched_cellpose_unique,1), cellpose_centroids(matched_cellpose_unique,2), ...
            'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [0 1 0]); % vert = match
    end
    if ~isempty(unmatched_cellpose_idx)
        plot(cellpose_centroids(unmatched_cellpose_idx,1), cellpose_centroids(unmatched_cellpose_idx,2), ...
            'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [1 0 0]); % rouge = no match
    end

    title('GCaMP (vert = vrai, orange = faux, croix vertes = match Cellpose, rouges = sans match)');
    xlabel('X'); ylabel('Y');
    set(gca, 'YDir', 'reverse');
    hold off;

    % --- Subplot 2: Cellpose sur aligned_image ---
    subplot(1, 2, 2);
    hold on;
    imagesc(aligned_image); colormap gray; axis image;

    % --- Outlines Cellpose (bleu) ---
    for ncell = 1:length(outline_x_cellpose)
        if ~isempty(outline_x_cellpose{ncell})
            plot(outline_x_cellpose{ncell}, outline_y_cellpose{ncell}, '-', 'LineWidth', 0.5, 'Color', [0 0 1]);
        end
    end

    % --- Croix verte : Cellpose avec correspondance GCaMP (vraie ou fausse) ---
    if ~isempty(matched_cellpose_unique)
        plot(cellpose_centroids(matched_cellpose_unique,1), cellpose_centroids(matched_cellpose_unique,2), ...
            'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [0 1 0]);
    end

    % --- Croix rouge : Cellpose sans correspondance ---
    if ~isempty(unmatched_cellpose_idx)
        plot(cellpose_centroids(unmatched_cellpose_idx,1), cellpose_centroids(unmatched_cellpose_idx,2), ...
            'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [1 0 0]);
    end

    title(sprintf('Cellpose sur aligned_image (IoU: %.4f)', IoU));
    xlabel('X'); ylabel('Y');
    set(gca, 'YDir', 'reverse');
    hold off;
    drawnow;

    % ---- Sauvegarde figure ----
    fig_name = sprintf('GCaMP_vs_Cellpose_group%d', m);
    save_path = fullfile(gcamp_output_folders{m}, [fig_name, '.png']);
    saveas(gcf, save_path);
    uiwait(gcf);

     % ---- Créer is_cell_blue à partir de iscell_gcamp ----
    is_cell_blue = nan(size(cellpose_props, 1), 1);  % Initialise avec NaN pour les non-appariés

    % Remplir selon les correspondances (vraies ou fausses)
    for i = 1:length(matched_cellpose_idx_all)
        gcamp_idx = matched_all_gcamp_idx(i);
        cellpose_idx = matched_cellpose_idx_all(i);

        if gcamp_idx <= numel(iscell_gcamp)
            % Vraie cellule GCaMP
            is_cell_blue(cellpose_idx) = iscell_gcamp(gcamp_idx);
        else
            % Faux positif GCaMP
            is_cell_blue(cellpose_idx) = NaN; % ou 0 si tu préfères
        end
    end

catch ME
    fprintf('Erreur dans le groupe %d: %s\n', m, ME.message);
    matched_gcamp_idx = [];
    matched_cellpose_idx_all = [];
end
end
