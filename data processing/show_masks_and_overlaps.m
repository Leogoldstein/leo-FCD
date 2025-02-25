function [matched_cellpose_idx, matched_gcamp_idx] = show_masks_and_overlaps(all_gcamp_props, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose, all_outline_gcampx, all_outline_gcampy, numFolders, valid_indices, all_meanImg, aligned_images) 

    % Définir un rayon d'influence pour la correspondance des centroids
    R = 5; % Ajustable en fonction de la résolution et des tailles cellulaires
  
    % Initialize variables to store matched indices
    matched_cellpose_idx = [];
    matched_gcamp_idx = [];
    
    n = 0;
    for m = 1:numFolders  
        % Check if m corresponds to a valid index from the validIndex list
        if ismember(m, valid_indices)
            try
                n = n+1;
                % Extraire les données du groupe
                gcamp_props = all_gcamp_props{m};
                cellpose_props = all_props_cellpose{n};
                meanImg = all_meanImg{1, n};
    
                % Vérifier si les centroids existent
                if isempty(gcamp_props) || isempty(cellpose_props)
                    fprintf('Skipping group %d: No centroids found.\n', m);
                    continue;
                end
                
                % Extraire les centroids sous forme de matrice Nx2
                gcamp_centroids = cat(1, gcamp_props.Centroid); % Nx2
                cellpose_centroids = cat(1, cellpose_props.Centroid); % Mx2
    
                % Calculer les distances entre chaque pair de centroids
                D = pdist2(gcamp_centroids, cellpose_centroids);
    
                % Trouver les centroids qui se chevauchent dans le rayon R
                [matched_gcamp_idx, matched_cellpose_idx] = find(D < R);
    
                % Calculer l'Intersection (nombre de centroids GCaMP appariés)
                intersection = length(unique(matched_gcamp_idx));
    
                % Calculer l'Union (total unique centroids)
                total_gcamp = size(gcamp_centroids, 1);
                total_cellpose = size(cellpose_centroids, 1);
                union = total_gcamp + total_cellpose - intersection;
    
                % Calculer l'IoU
                IoU = intersection / union;
    
                % Créer une figure avec deux sous-graphes
                figure;
    
                % ---- Subplot 1: GCaMP sur meanImg ----
                subplot(1, 2, 1);
                hold on;
                imagesc(meanImg);
                colormap gray;
                axis image;
    
                % Tracer les contours GCaMP (vert)
                for ncell = 1:length(all_outline_gcampx{m})
                    plot(all_outline_gcampx{m}{ncell}, all_outline_gcampy{m}{ncell}, '.', 'MarkerSize', 1, 'Color', 'g');
                end
    
                % Tracer les centroids GCaMP (vert)
                for ncell = 1:length(gcamp_props)
                    plot(gcamp_props(ncell).Centroid(1), gcamp_props(ncell).Centroid(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'g');
                end
    
                % Mettre en évidence les centroids appariés (rouge)
                plot(gcamp_centroids(matched_gcamp_idx,1), gcamp_centroids(matched_gcamp_idx,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    
                % Format du graphique
                title('GCaMP sur meanImg');
                xlabel('X Coordinate');
                ylabel('Y Coordinate');
                set(gca, 'YDir', 'reverse');
                hold off;
    
                % ---- Subplot 2: Cellpose sur aligned_image ----
                subplot(1, 2, 2);
                hold on;
                imagesc(aligned_images{m});
                colormap gray;
                axis image;
    
                % Tracer les contours Cellpose (bleu)
                for ncell = 1:length(all_outlines_x_cellpose{n})
                    plot(all_outlines_x_cellpose{n}{ncell}, all_outlines_y_cellpose{n}{ncell}, '.', 'MarkerSize', 1, 'Color', 'b');
                end
    
                % Tracer les centroids Cellpose (bleu)
                for ncell = 1:length(cellpose_props)
                    plot(cellpose_props(ncell).Centroid(1), cellpose_props(ncell).Centroid(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'b');
                end
    
                % Mettre en évidence les centroids appariés (rouge)
                plot(cellpose_centroids(matched_cellpose_idx,1), cellpose_centroids(matched_cellpose_idx,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    
                % Format du graphique
                title(sprintf('Cellpose sur aligned_image (IoU: %.4f)', IoU));
                xlabel('X Coordinate');
                ylabel('Y Coordinate');
                set(gca, 'YDir', 'reverse');
                hold off;
    
            catch ME
                % Gestion des erreurs
                fprintf('Erreur dans le groupe %d: %s\n', m, ME.message);
            end
        end
    end
end
