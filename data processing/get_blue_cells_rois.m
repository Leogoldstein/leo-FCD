function [DF_blue, DF_gcamp_not_blue] = get_blue_cells_rois(DF_gcamp, matched_gcamp_idx, matched_cellpose_idx, ncells_cellpose, mask_cellpose, currentTSeriesPath)
    [~, num_frames] = size(DF_gcamp);
    
    used_gcamp_indices = unique(matched_gcamp_idx);
    DF_gcamp_not_blue = DF_gcamp;
    DF_gcamp_not_blue(used_gcamp_indices, :) = [];
    
    if iscell(ncells_cellpose)
        ncells_cellpose = ncells_cellpose{1};
    end
    
    DF_blue = NaN(ncells_cellpose, num_frames);
    
    unmatched_gcamp_idx = [];
    
    for ncell_cellpose = 1:ncells_cellpose
        if ~ismember(ncell_cellpose, matched_cellpose_idx)
            unmatched_gcamp_idx = [unmatched_gcamp_idx, ncell_cellpose];  
            %disp(['Aucune correspondance pour la cellule Cellpose ' num2str(ncell_cellpose)]);
        %else
            % matched_gcamp_index = matched_gcamp_idx(matched_cellpose_idx == ncell_cellpose);                    
            % disp(['Correspondance trouvée entre la cellule Cellpose ' num2str(ncell_cellpose) ' et la/les cellule(s) gcamp ' num2str(matched_gcamp_index(:)')]);
            % if isscalar(matched_gcamp_index)
            %     % Assign directly if only one match
            %     DF_blue(ncell_cellpose, :) = DF_gcamp(matched_gcamp_index, :);
            % else
            %    % If multiple matches, compute the mean (or another aggregation method)
            %     DF_blue(ncell_cellpose, :) = mean(DF_gcamp(matched_gcamp_index, :), 1);
            % end
        end
    end
    
    tiffFiles = dir(fullfile(currentTSeriesPath, '*.tif'));
    tiffFiles = {tiffFiles(~contains({tiffFiles.name}, 'companion.ome')).name};  
    [~, idxOrder] = sort(tiffFiles);  
    tiffFiles = tiffFiles(idxOrder);
    
    image_idx = 1;
    for tIdx = 1:numel(tiffFiles)
        filename = fullfile(currentTSeriesPath, tiffFiles{tIdx});
        disp(filename);
        
        info = imfinfo(filename);
        num_pages = numel(info);
        height = info(1).Height;
        width = info(1).Width;
        
        F = zeros(height, width, num_pages);
        mean_image_stack = zeros(height, width, 50);
        
        for page = 1:num_pages
            F(:, :, page) = imread(filename, 'Index', page);
            
            if page <= 50
                mean_image_stack(:, :, page) = F(:, :, page);
            end
            
            for ncell = 1:ncells_cellpose
                [y, x] = find(mask_cellpose{ncell});
                cellDF = mean(F(y, x, page), 'all');  
                DF_blue(ncell, image_idx) = cellDF;
            end

            % Affichage de l'image moyenne à la 50ème image
            % if page == 50 && tIdx==1
            %      mean_image = mean(mean_image_stack, 3);
            % 
            %      figure;
            %      set(gcf, 'Position', get(0, 'ScreenSize'));  % Met la figure en plein écran
            %      imshow(mean_image, []);
            %      hold on;
            %      title('Appuie sur Espace pour afficher chaque cellule');
            % 
            %      % Boucle pour afficher une cellule à la fois
            %      for ncell = 1:ncells_cellpose
            %          [y, x] = find(mask_cellpose{ncell});
            % 
            %          if ~isempty(x) && ~isempty(y)
            %              plot(x, y, 'r.', 'MarkerSize', 10, 'LineWidth', 2);
            %          else
            %              disp(['⚠ Aucun pixel trouvé pour la cellule ', num2str(ncell)]);
            %          end
            % 
            %          % Attendre un appui sur la touche Espace avant de continuer
            %          waitforbuttonpress;
            %          key = get(gcf, 'CurrentCharacter');
            %          if key ~= ' '  % Si ce n'est pas la touche espace, on sort de la boucle
            %              break;
            %          end
            %      end
            %      %set(gca, 'YDir', 'reverse');
            %      hold off;
            % end

            image_idx = image_idx + 1;
        end
    end
    
    % unmatched_cells_data = DF_blue(unmatched_gcamp_idx, :);
    % 
    % processed_unmatched_cells_data = DF_processing(unmatched_cells_data);
    % 
    % DF_blue(unmatched_gcamp_idx, :) = processed_unmatched_cells_data;

    if ~ismissing(DF_blue)
        [num_cells, ~] = size(DF_blue);
        figure;
        hold on;
        for cell_idx = 1:num_cells
            plot(DF_blue(cell_idx, :), 'DisplayName', ['Cell ' num2str(cell_idx)]);
        end
        hold off;
        xlabel('Frame Number');
        ylabel('Fluorescence Intensity');
        title('DF_blue for Group');
        legend show;
    end
end