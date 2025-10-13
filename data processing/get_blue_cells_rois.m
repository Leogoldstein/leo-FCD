function [F_blue, num_cells_mask, mask_cellpose, props_cellpose, outlines_x_cellpose, outlines_y_cellpose] = ...
    get_blue_cells_rois(F_gcamp, matched_cellpose_idx, ncells_cellpose, mask_cellpose_all, ...
                        props_cellpose_all, outlines_x_all, outlines_y_all, currentTSeriesPath, mode)
% get_blue_cells_rois : extrait les intensités de fluorescence des cellules Cellpose
% et réactualise les structures associées selon le mode choisi.
%
% Entrées :
%   - F_gcamp            : matrice fluorescence GCaMP (n_cells x n_frames)
%   - matched_cellpose_idx : indices des cellules Cellpose appariées
%   - ncells_cellpose    : nombre total de cellules Cellpose
%   - mask_cellpose_all  : masque binaire (cell array, 1 par ROI)
%   - props_cellpose_all : structure regionprops de Cellpose
%   - outlines_x_all, outlines_y_all : coordonnées de contour de chaque ROI
%   - currentTSeriesPath : chemin vers les fichiers TIF
%   - mode (optionnel)   : 'matched' (défaut) ou 'all'
%
% Sorties :
%   - F_blue : matrice fluorescence des cellules Cellpose sélectionnées
%   - num_cells_mask, mask_cellpose, props_cellpose, outlines_x_cellpose, outlines_y_cellpose :
%     structures Cellpose filtrées selon le mode

    if nargin < 9 || isempty(mode)
        mode = 'matched';
    end

    % --- Vérification du type de ncells_cellpose ---
    if iscell(ncells_cellpose)
        ncells_cellpose = ncells_cellpose{1};
    end

    % --- Nettoyage des indices appariés ---
    matched_cellpose_idx = unique(matched_cellpose_idx);
    matched_cellpose_idx = matched_cellpose_idx(matched_cellpose_idx > 0 & matched_cellpose_idx <= ncells_cellpose);

    % --- Sélection du mode ---
    switch lower(mode)
        case 'matched'
            if isempty(matched_cellpose_idx)
                warning('Aucune cellule Cellpose appariée trouvée.');
                F_blue = [];
                num_cells_mask = 0;
                mask_cellpose = {};
                props_cellpose = struct([]);
                outlines_x_cellpose = {};
                outlines_y_cellpose = {};
                return;
            end
            selected_cells = matched_cellpose_idx;
            fprintf('Extraction de %d cellules Cellpose appariées.\n', numel(selected_cells));

        case 'all'
            selected_cells = 1:ncells_cellpose;
            fprintf('Extraction de toutes les %d cellules Cellpose (appariées et non appariées).\n', ncells_cellpose);

        otherwise
            error('Mode invalide : utilisez "matched" ou "all".');
    end

    % --- Mise à jour des structures Cellpose ---
    num_cells_mask = numel(selected_cells);
    mask_cellpose = mask_cellpose_all(selected_cells);
    if nargin >= 5 && ~isempty(props_cellpose_all)
        props_cellpose = props_cellpose_all(selected_cells);
    else
        props_cellpose = struct([]);
    end
    outlines_x_cellpose = outlines_x_all(selected_cells);
    outlines_y_cellpose = outlines_y_all(selected_cells);

    % --- Préparation de la matrice de sortie ---
    [~, num_frames] = size(F_gcamp);
    F_blue = NaN(length(selected_cells), num_frames);

    % --- Lister les fichiers TIFF valides ---
    tiffFilesStruct = dir(fullfile(currentTSeriesPath, '*.tif'));
    fileNames = {tiffFilesStruct.name};
    excludeMask = contains(fileNames, 'companion.ome') | contains(fileNames, 'Concatenated');
    tiffFiles = fileNames(~excludeMask);
    [~, idxOrder] = sort(tiffFiles);
    tiffFiles = tiffFiles(idxOrder);

    image_idx = 1;

    % --- Parcours des TIF ---
    for tIdx = 1:numel(tiffFiles)
        filename = fullfile(currentTSeriesPath, tiffFiles{tIdx});
        fprintf('Lecture : %s\n', filename);

        info = imfinfo(filename);
        num_pages = numel(info);

        for page = 1:num_pages
            pixel_val = imread(filename, 'Index', page);

            % --- Calcul de fluorescence pour chaque cellule sélectionnée ---
            for j = 1:length(selected_cells)
                ncell = selected_cells(j);
                if ncell > numel(mask_cellpose_all) || isempty(mask_cellpose_all{ncell})
                    F_blue(j, image_idx) = NaN;
                    continue;
                end

                [y, x] = find(mask_cellpose_all{ncell});
                if ~isempty(x)
                    F_blue(j, image_idx) = mean(pixel_val(y, x), 'all');
                else
                    F_blue(j, image_idx) = NaN;
                end
            end

            image_idx = image_idx + 1;
        end
    end

    % --- (Optionnel) affichage rapide ---
    %{
    if ~isempty(F_blue)
        figure('Name', sprintf('F\\_blue (%s)', mode));
        hold on;
        for c = 1:size(F_blue, 1)
            plot(F_blue(c, :), 'DisplayName', sprintf('Cell %d', selected_cells(c)));
        end
        hold off;
        xlabel('Frame');
        ylabel('Fluorescence');
        title(sprintf('F\\_blue (%s Cellpose ROIs)', mode));
        legend show;
    end
    %}
end
