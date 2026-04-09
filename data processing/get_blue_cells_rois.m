function F_blue = get_blue_cells_rois(F_gcamp, matched_cellpose_idx, ncells_cellpose, mask_cellpose_p, ...
                        props_cellpose_p, outlines_x_p, outlines_y_p, gcamp_planes_for_session_m, mode)

% get_blue_cells_rois
% Extrait les intensités de fluorescence des cellules Cellpose
% à partir des fichiers TIFF du dossier reg_tif.
%
% Entrées :
%   - F_gcamp              : matrice fluorescence GCaMP (n_cells x n_frames)
%   - matched_cellpose_idx : indices des cellules Cellpose appariées
%   - ncells_cellpose      : nombre total de cellules Cellpose
%   - mask_cellpose_p      : soit
%                               * cell array {N x 1}, chaque élément = masque [H x W]
%                               * stack logique [N x H x W]
%   - props_cellpose_p     : structure regionprops de Cellpose
%   - outlines_x_p/y_p     : contours de chaque ROI
%   - gcamp_planes_for_session_m : chemin du plan contenant reg_tif
%   - mode                 : 'matched' (défaut) ou 'all'
%
% Sortie :
%   - F_blue : matrice fluorescence des cellules Cellpose sélectionnées

    if nargin < 9 || isempty(mode)
        mode = 'matched';
    end

    if nargin < 2 || isempty(matched_cellpose_idx)
        matched_cellpose_idx = [];
    end

    % --- Vérification / conversion ncells_cellpose ---
    if iscell(ncells_cellpose)
        ncells_cellpose = ncells_cellpose{1};
    end
    ncells_cellpose = double(ncells_cellpose);

    % --- Nombre réel de masques disponibles ---
    n_masks_available = get_num_masks(mask_cellpose_p);

    if isempty(ncells_cellpose) || ~isscalar(ncells_cellpose) || ~isfinite(ncells_cellpose) || ncells_cellpose < 0
        ncells_cellpose = n_masks_available;
    end

    % borne par le nombre réel de masques
    ncells_cellpose = min(ncells_cellpose, n_masks_available);

    % --- Nettoyage des indices appariés ---
    matched_cellpose_idx = unique(round(matched_cellpose_idx(:)));
    matched_cellpose_idx = matched_cellpose_idx( ...
        matched_cellpose_idx >= 1 & matched_cellpose_idx <= ncells_cellpose);

    % --- Sélection du mode ---
    switch lower(mode)
        case 'matched'
            if isempty(matched_cellpose_idx)
                warning('Aucune cellule Cellpose appariée trouvée.');
                F_blue = [];
                return;
            end
            selected_cells = matched_cellpose_idx;
            fprintf('Extraction de %d cellules Cellpose appariées.\n', numel(selected_cells));

        case 'all'
            selected_cells = (1:ncells_cellpose)';
            fprintf('Extraction de toutes les %d cellules Cellpose sélectionnables.\n', numel(selected_cells));

        otherwise
            error('Mode invalide : utilisez "matched" ou "all".');
    end

    % --- Préparation matrice de sortie ---
    [~, num_frames_expected] = size(F_gcamp);
    F_blue = NaN(numel(selected_cells), num_frames_expected);

    % --- Résoudre le dossier reg_tif ---
    if iscell(gcamp_planes_for_session_m)
        if isempty(gcamp_planes_for_session_m)
            error('gcamp_planes_for_session_m est vide.');
        end
        gcamp_planes_for_session_m = gcamp_planes_for_session_m{1};
    end

    reg_tif_dir = fullfile(gcamp_planes_for_session_m, 'reg_tif');
    if ~isfolder(reg_tif_dir)
        error('Dossier reg_tif introuvable: %s', reg_tif_dir);
    end

    % --- Lister les TIFF valides ---
    tiffFilesStruct = dir(fullfile(reg_tif_dir, '*.tif'));
    if isempty(tiffFilesStruct)
        warning('Aucun fichier TIFF trouvé dans %s', reg_tif_dir);
        F_blue = [];
        return;
    end

    tiffFiles = {tiffFilesStruct.name};
    numbers = nan(numel(tiffFiles),1);

    for i = 1:numel(tiffFiles)
        name = tiffFiles{i};
        tokens = regexp(name, 'file(\d+)_chan', 'tokens', 'once');
        if ~isempty(tokens)
            numbers(i) = str2double(tokens{1});
        else
            % fallback : garder ces fichiers à la fin
            numbers(i) = inf;
        end
    end

    [~, idxOrder] = sort(numbers);
    tiffFiles = tiffFiles(idxOrder);

    % --- Parcours des TIFF ---
    image_idx = 1;

    for tIdx = 1:numel(tiffFiles)
        filename = fullfile(reg_tif_dir, tiffFiles{tIdx});
        fprintf('Lecture : %s\n', filename);

        info = imfinfo(filename);
        num_pages = numel(info);

        for page = 1:num_pages
            pixel_val = imread(filename, 'Index', page);

            % éviter dépassement si F_gcamp donne une longueur attendue plus courte
            if image_idx > size(F_blue, 2)
                % on agrandit proprement au besoin
                F_blue(:, end+1) = NaN;
            end

            % --- Calcul fluorescence pour chaque cellule sélectionnée ---
            for j = 1:numel(selected_cells)
                ncell = selected_cells(j);

                current_mask = get_mask_at(mask_cellpose_p, ncell);

                if isempty(current_mask)
                    F_blue(j, image_idx) = NaN;
                    continue;
                end

                current_mask = logical(current_mask);

                if size(current_mask,1) ~= size(pixel_val,1) || size(current_mask,2) ~= size(pixel_val,2)
                    error('Taille incompatible entre masque Cellpose %d [%d %d] et image TIFF [%d %d].', ...
                        ncell, size(current_mask,1), size(current_mask,2), size(pixel_val,1), size(pixel_val,2));
                end

                vals = pixel_val(current_mask);
                if isempty(vals)
                    F_blue(j, image_idx) = NaN;
                else
                    F_blue(j, image_idx) = mean(double(vals), 'all');
                end
            end

            image_idx = image_idx + 1;
        end
    end

    % tronquer si trop large
    if image_idx <= size(F_blue, 2)
        F_blue = F_blue(:, 1:image_idx-1);
    end

    % % --- Affichage rapide optionnel ---
    % if ~isempty(F_blue)
    %     figure('Name', sprintf('F_blue (%s)', mode));
    %     hold on;
    %     for c = 1:size(F_blue, 1)
    %         plot(F_blue(c, :), 'DisplayName', sprintf('Cell %d', selected_cells(c)));
    %     end
    %     hold off;
    %     xlabel('Frame');
    %     ylabel('Fluorescence');
    %     title(sprintf('F_blue (%s Cellpose ROIs)', mode));
    %     legend show;
    % end
end

% =========================================================
% ================= FONCTIONS LOCALES =====================
% =========================================================

function n = get_num_masks(mask_cellpose_p)
    if isempty(mask_cellpose_p)
        n = 0;
        return;
    end

    if iscell(mask_cellpose_p)
        n = numel(mask_cellpose_p);
        return;
    end

    if isnumeric(mask_cellpose_p) || islogical(mask_cellpose_p)
        if ndims(mask_cellpose_p) == 2
            n = 1;
        elseif ndims(mask_cellpose_p) == 3
            n = size(mask_cellpose_p, 1);
        else
            error('mask_cellpose_p doit être 2D, 3D, ou cell array. Reçu ndims=%d.', ndims(mask_cellpose_p));
        end
        return;
    end

    error('Type de mask_cellpose_p non supporté: %s', class(mask_cellpose_p));
end

function M = get_mask_at(mask_cellpose_p, idx)
    M = [];

    if isempty(mask_cellpose_p) || idx < 1 || ~isfinite(idx)
        return;
    end

    idx = round(idx);

    if iscell(mask_cellpose_p)
        if idx > numel(mask_cellpose_p)
            return;
        end
        M = mask_cellpose_p{idx};
        return;
    end

    if isnumeric(mask_cellpose_p) || islogical(mask_cellpose_p)
        if ndims(mask_cellpose_p) == 2
            if idx == 1
                M = mask_cellpose_p;
            end
            return;
        elseif ndims(mask_cellpose_p) == 3
            if idx > size(mask_cellpose_p, 1)
                return;
            end
            M = squeeze(mask_cellpose_p(idx,:,:));
            return;
        end
    end

    error('Type de mask_cellpose_p non supporté: %s', class(mask_cellpose_p));
end