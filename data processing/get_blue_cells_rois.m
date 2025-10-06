function F_blue = get_blue_cells_rois(F_gcamp, matched_cellpose_idx, ncells_cellpose, mask_cellpose, currentTSeriesPath)
    % get_blue_cells_rois : extrait les intensités de fluorescence pour
    % chaque cellule Cellpose correspondant à un match GCaMP
    %
    % Entrées :
    %   - F_gcamp : matrice fluorescence GCaMP (n_cells x n_frames)
    %   - matched_cellpose_idx : indices des cellules Cellpose appariées
    %   - ncells_cellpose : nombre total de cellules Cellpose
    %   - mask_cellpose : masque binaire de chaque ROI Cellpose
    %   - currentTSeriesPath : chemin vers les fichiers TIF
    
    % --- Vérification du type de ncells_cellpose ---
    if iscell(ncells_cellpose)
        ncells_cellpose = ncells_cellpose{1};
    end
    
    % --- Nettoyage des indices appariés ---
    matched_cellpose_idx = unique(matched_cellpose_idx);
    matched_cellpose_idx = matched_cellpose_idx(matched_cellpose_idx > 0 & matched_cellpose_idx <= ncells_cellpose);
    
    if isempty(matched_cellpose_idx)
        warning('Aucune cellule Cellpose appariée trouvée.');
        F_blue = [];
        return;
    end
    
    % --- Préparation de la matrice de sortie ---
    [~, num_frames] = size(F_gcamp);
    F_blue = NaN(length(matched_cellpose_idx), num_frames);
    
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
        disp(['Lecture : ', filename]);
        
        info = imfinfo(filename);
        num_pages = numel(info);
        height = info(1).Height;
        width = info(1).Width;
        
        % Lecture image par image
        for page = 1:num_pages
            pixel_val = imread(filename, 'Index', page);
            
            % --- Calcul de fluorescence pour chaque cellule Cellpose appariée ---
            for j = 1:length(matched_cellpose_idx)
                ncell = matched_cellpose_idx(j);
                [y, x] = find(mask_cellpose{ncell});
                if ~isempty(x)
                    F_blue(j, image_idx) = mean(pixel_val(y, x), 'all');
                else
                    F_blue(j, image_idx) = NaN;
                end
            end
            
            image_idx = image_idx + 1;
        end
    end
    
    % --- Visualisation rapide ---
    % if ~isempty(F_blue)
    %     figure('Name', 'F\_blue (matched Cellpose only)');
    %     hold on;
    %     for c = 1:size(F_blue, 1)
    %         plot(F_blue(c, :), 'DisplayName', sprintf('Cell %d', matched_cellpose_idx(c)));
    %     end
    %     hold off;
    %     xlabel('Frame');
    %     ylabel('Fluorescence');
    %     title('F\_blue - matched Cellpose ROIs');
    %     legend show;
    % end
end
