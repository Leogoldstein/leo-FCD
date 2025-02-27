function [all_DF_blue, all_Raster_blue, all_MAct_blue, all_DF_gcamp_not_blue] = get_blue_cells_rois(gcamp_output_folders, valid_indices, current_gcamp_TSeries_path, all_num_cells_masks, all_mask_cellpose, all_matched_cellpose_idx, all_matched_gcamp_idx, all_DF, MinPeakDistance, all_synchronous_frames)

    numPaths = length(gcamp_output_folders);
    all_DF_blue = cell(1, numPaths); 
    all_Raster_blue = cell(1, numPaths); 
    all_MAct_blue = cell(1, numPaths); 
    all_DF_gcamp_not_blue = cell(1, numPaths); 
    n = 0;
    for idx = 1:numPaths     
        if ismember(idx, valid_indices)        
            n = n+1;
            DF_gcamp = all_DF{idx};
            synchronous_frames = all_synchronous_frames{idx};
            [~, num_frames] = size(DF_gcamp);
            
            matched_cellpose_idx = all_matched_cellpose_idx{n};
            matched_gcamp_idx = all_matched_gcamp_idx{n};
            
            used_gcamp_indices = unique(matched_gcamp_idx);
            DF_gcamp_not_blue= DF_gcamp;
            DF_gcamp_not_blue(used_gcamp_indices, :) = [];
                 
            currentgcampOutputPath = gcamp_output_folders{idx};
            disp(currentgcampOutputPath)
            currentTSeriesPath = current_gcamp_TSeries_path{idx};

            ncells_cellpose = all_num_cells_masks{n};
            % Ensure it's numeric
            if iscell(ncells_cellpose)
                ncells_cellpose = ncells_cellpose{1}; % Extract if it's a cell
            end

            DF_blue = NaN(ncells_cellpose, num_frames);
            Raster_blue = NaN(ncells_cellpose, num_frames);
            MAct_blue = NaN(ncells_cellpose, num_frames);
            
            mask_cellpose = all_mask_cellpose{n};
    
            unmatched_gcamp_idx = [];

            for ncell_cellpose = 1:ncells_cellpose
                if ismember(ncell_cellpose, matched_cellpose_idx)
                    % matched_gcamp_index = matched_gcamp_idx(matched_cellpose_idx == ncell_cellpose);                    
                    % disp(['Correspondance trouvée entre la cellule Cellpose ' num2str(ncell_cellpose) ' et la/les cellule(s) gcamp ' num2str(matched_gcamp_index(:)')]);
                    % if isscalar(matched_gcamp_index)
                    %     % Assign directly if only one match
                    %     DF_blue(ncell_cellpose, :) = DF_gcamp(matched_gcamp_index, :);
                    % else
                    %    % If multiple matches, compute the mean (or another aggregation method)
                    %     DF_blue(ncell_cellpose, :) = mean(DF_gcamp(matched_gcamp_index, :), 1);
                    % end
                else
                    unmatched_gcamp_idx = [unmatched_gcamp_idx, ncell_cellpose];  
                    %disp(['Aucune correspondance pour la cellule Cellpose ' num2str(ncell_cellpose)]);
                end
            end
            % 
            %if ~isempty(unmatched_gcamp_idx)
            tiffFiles = dir(fullfile(currentTSeriesPath, '*.tif'));
            tiffFiles = {tiffFiles(~contains({tiffFiles.name}, 'companion.ome')).name};  
            [~, idxOrder] = sort(tiffFiles);  
            tiffFiles = tiffFiles(idxOrder);  

            total_images = 0;
            for tIdx = 1:numel(tiffFiles)
                filename = fullfile(currentTSeriesPath, tiffFiles{tIdx});
                info = imfinfo(filename);
                total_images = total_images + numel(info);
            end

            image_idx = 1;  % Initialiser l'indice d'image
            % Pour chaque fichier TIFF dans tiffFiles
            for tIdx = 1:numel(tiffFiles)
                filename = fullfile(currentTSeriesPath, tiffFiles{tIdx});
                disp(filename);
                
                % Lire les informations de l'image
                info = imfinfo(filename);
                num_pages = numel(info);
                height = info(1).Height;
                width = info(1).Width;
                
                F = zeros(height, width, num_pages);  % Initialiser le tableau de données pour l'image
                mean_image_stack = zeros(height, width, 50);
                
                % Lire les pages du TIFF
                for page = 1:num_pages
                    F(:, :, page) = imread(filename, 'Index', page);
                    
                    % Ajouter l'image à l'empilement des images pour les 50 premières
                    if page <= 50
                        mean_image_stack(:, :, page) = F(:, :, page);
                    end
                    
                    % Calculer DF pour chaque cellule (ajuster cette partie si nécessaire)
                    for ncell = 1:ncells_cellpose
            
                        % Trouver les indices des pixels contenant '1' (dans le masque Cellpose)
                        [y, x] = find(mask_cellpose{ncell});
                        
                        % Calculer la valeur moyenne pour la cellule
                        cellDF = mean(F(y, x, page), 'all');  
                        DF_blue(ncell, image_idx) = cellDF;
                    end
                    
                    % Affichage de l'image moyenne à la 50ème image
                   if page == 50 && tIdx==1
                        mean_image = mean(mean_image_stack, 3);
                        
                        figure;
                        set(gcf, 'Position', get(0, 'ScreenSize'));  % Met la figure en plein écran
                        imshow(mean_image, []);
                        hold on;
                        title('Appuie sur Espace pour afficher chaque cellule');
                        
                        % Boucle pour afficher une cellule à la fois
                        for ncell = 1:ncells_cellpose
                            [y, x] = find(mask_cellpose{ncell});
                            
                            if ~isempty(x) && ~isempty(y)
                                plot(x, y, 'r.', 'MarkerSize', 10, 'LineWidth', 2);
                            else
                                disp(['⚠ Aucun pixel trouvé pour la cellule ', num2str(ncell)]);
                            end
                            
                            % Attendre un appui sur la touche Espace avant de continuer
                            waitforbuttonpress;
                            key = get(gcf, 'CurrentCharacter');
                            if key ~= ' '  % Si ce n'est pas la touche espace, on sort de la boucle
                                break;
                            end
                        end
                        %set(gca, 'YDir', 'reverse');
                        hold off;
                   end

                    % Mettre à jour l'indice de l'image
                    image_idx = image_idx + 1;
                end
            end

            unmatched_cells_data = DF_blue(unmatched_gcamp_idx, :);

            processed_unmatched_cells_data = DF_processing(unmatched_cells_data);
            
            DF_blue(unmatched_gcamp_idx, :) = processed_unmatched_cells_data;

            [Raster_blue, MAct_blue, ~] = Sumactivity(DF_blue, MinPeakDistance, synchronous_frames);

            all_DF_blue{idx} = DF_blue;
            all_Raster_blue{idx} = Raster_blue;
            all_MAct_blue{idx} = MAct_blue;
            all_DF_gcamp_not_blue{idx} = DF_gcamp_not_blue;
            
            save(fullfile(currentgcampOutputPath, 'results_raster.mat'), "DF_blue", "DF_gcamp_not_blue", "Raster_blue", "MAct_blue", '-append');
        else
            all_DF_blue{idx} = [];
            all_Raster_blue{idx} = [];
            all_MAct_blue{idx} = [];
            all_DF_gcamp_not_blue{idx} = [];
        end
    end

    % Loop over each element in all_DF_blue
    for idx = 1:length(all_DF_blue)
        % Extract DF_blue for the current path
        DF_blue = all_DF_blue{idx};       
        if ~ismissing(DF_blue)
            % Number of frames (assuming rows are cells and columns are frames)
            [num_cells, ~] = size(DF_blue);
    
            % Create a figure for plotting
            figure;
    
            % Plot each cell's DF_blue (each row represents a cell)
            hold on;
            for cell_idx = 1:num_cells
                plot(DF_blue(cell_idx, :), 'DisplayName', ['Cell ' num2str(cell_idx)]);
            end
            hold off;
    
            % Add labels and title
            xlabel('Frame Number');
            ylabel('Fluorescence Intensity');
            title(['DF_blue for Group ' num2str(idx)]);
            legend show; % Show legend for each cell
        end
    end
end

