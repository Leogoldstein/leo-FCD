function compute_iou_between_centroids(all_gcamp_props, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose, all_outline_gcampx, all_outline_gcampy, date_group_paths)
    for m = 1:length(date_group_paths)
        try
            % Extraction des données pour le groupe m
            gcamp_props = all_gcamp_props{m};
            cellpose_props = all_props_cellpose{m};
            
            % Créer une nouvelle figure pour chaque groupe
            figure;
            hold on;
    
            % Tracer les outlines de Cellpose
            for ncell = 1:length(all_outlines_x_cellpose{m})
                % Extraire les coordonnées des outlines de Cellpose
                pixels_x = all_outlines_x_cellpose{m}{ncell};
                pixels_y = all_outlines_y_cellpose{m}{ncell};
                plot(pixels_x, pixels_y, '.', 'MarkerSize', 1, 'DisplayName', ['Cellpose Outline ', num2str(ncell)], 'Color', 'b');
            end
    
            % Tracer les outlines de GCaMP avec connexité à 8 voisins
            for ncell = 1:length(all_outline_gcampx{m})
                % Extraire les coordonnées des outlines de GCaMP
                pixels_x_gcamp = all_outline_gcampx{m}{ncell};
                pixels_y_gcamp = all_outline_gcampy{m}{ncell};
                
                % Vérifier que les coordonnées sont dans la plage de l'image
                max_x = max(pixels_x_gcamp);
                max_y = max(pixels_y_gcamp);
                
                % Créer une image binaire des contours de GCaMP
                outline_image = false(max_y, max_x);  % Image binaire avec les bonnes dimensions
                valid_indices = pixels_y_gcamp <= max_y & pixels_x_gcamp <= max_x;  % Vérifier que les indices sont dans la plage
                
                % Appliquer les indices valides à l'image binaire
                outline_image(sub2ind(size(outline_image), pixels_y_gcamp(valid_indices), pixels_x_gcamp(valid_indices))) = true;
                
                % Identifier les composants connexes dans l'image des contours de GCaMP
                cc_gcamp = bwconncomp(outline_image, 8);  % Connexité à 8 voisins
                
                % Relier les composants connexes en traçant les outlines
                for k = 1:cc_gcamp.NumObjects
                    % Extraire les pixels du composant courant
                    [y_gcamp, x_gcamp] = ind2sub(size(outline_image), cc_gcamp.PixelIdxList{k});
                    
                    % Tracer les pixels du composant
                    plot(x_gcamp, y_gcamp, '.', 'MarkerSize', 1, 'DisplayName', ['GCaMP Outline ', num2str(ncell)], 'Color', 'r');
                end
            end
    
            % Tracer les centroids de Cellpose
            for ncell = 1:length(cellpose_props)
                centroid_cellpose = cellpose_props(ncell).Centroid;
                plot(centroid_cellpose(1), centroid_cellpose(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', ['Cellpose Centroid ', num2str(ncell)], 'Color', 'g');
            end
    
            % Tracer les centroids de GCaMP
            for ncell = 1:length(gcamp_props)
                centroid_gcamp = gcamp_props(ncell).Centroid;
                plot(centroid_gcamp(1), centroid_gcamp(2), 'o', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', ['GCaMP Centroid ', num2str(ncell)], 'Color', 'm');
            end
            
            % Ajouter des titres et légendes
            title(['Superposition des outlines et centroids pour le groupe ', num2str(m)]);
            xlabel('X Coordinate');
            ylabel('Y Coordinate');
            
            % Inverser l'axe Y pour aligner correctement les cellules (inverse de l'orientation verticale)
            set(gca, 'YDir', 'reverse');

            % Maintenir la figure ouverte pour le prochain groupe
            hold off;
        catch ME
            % Gestion des erreurs avec catch
            fprintf('Erreur rencontrée pour le groupe %d : %s\n', m, ME.message);
        end
    end
end
