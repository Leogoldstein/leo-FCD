function show_masks(all_gcamp_props, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose, all_outline_gcampx, all_outline_gcampy, sorted_date_group_paths, all_meanImg, aligned_images)

    % Initialisation des résultats
    % cell_indices_below_threshold = {}; % Liste des cellules avec IoU ≤ 3 pixels

    for m = 1:length(sorted_date_group_paths)
        try
            % Extraction des données pour le groupe m
            gcamp_props = all_gcamp_props{m};
            cellpose_props = all_props_cellpose{m};

            meanImg = all_meanImg{1,m};

            % Calcul des distances entre les centroides
            gcamp_centroids = vertcat(gcamp_props.Centroid); % Matrice [n x 2]
            cellpose_centroids = vertcat(cellpose_props.Centroid); % Matrice [m x 2]

            % Matrice des distances
            distances = pdist2(gcamp_centroids, cellpose_centroids); % Taille [n x m]

            % Trouver les paires avec une distance ≤ 3 pixels
            % [gcamp_idx, cellpose_idx] = find(distances <= 3); % Indices des paires
            % cell_indices_below_threshold{m} = struct( ...
            %     'GCaMP', gcamp_idx, ...
            %     'Cellpose', cellpose_idx, ...
            %     'Distances', distances(gcamp_idx + (cellpose_idx - 1) * size(distances, 1)) ...
            % );

            % Créer une nouvelle figure pour chaque groupe avec 2 sous-figures côte à côte
            figure;

            % Subplot 1: GCaMP sur meanImg
            subplot(1, 2, 1);
            hold on;
            imagesc(meanImg);
            colormap gray;
            axis image;
            
            % Tracer les outlines de GCaMP en vert
            for ncell = 1:length(all_outline_gcampx{m})
                pixels_x_gcamp = all_outline_gcampx{m}{ncell};
                pixels_y_gcamp = all_outline_gcampy{m}{ncell};
                plot(pixels_x_gcamp, pixels_y_gcamp, '.', 'MarkerSize', 1, 'Color', 'g');
            end

            % Tracer les centroids de GCaMP en vert
            for ncell = 1:length(gcamp_props)
                centroid_gcamp = gcamp_props(ncell).Centroid;
                plot(centroid_gcamp(1), centroid_gcamp(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'g');
            end

            % Titre et ajustement des axes
            title('GCaMP sur meanImg');
            xlabel('X Coordinate');
            ylabel('Y Coordinate');
            set(gca, 'YDir', 'reverse'); % Inverser l'axe Y pour un alignement correct
            hold off;

            % Subplot 2: Cellpose sur aligned_images
            subplot(1, 2, 2);
            hold on;
            imagesc(aligned_images{m});
            colormap gray;
            axis image;
            
            % Tracer les outlines de Cellpose en bleu
            for ncell = 1:length(all_outlines_x_cellpose{m})
                pixels_x = all_outlines_x_cellpose{m}{ncell};
                pixels_y = all_outlines_y_cellpose{m}{ncell};
                plot(pixels_x, pixels_y, '.', 'MarkerSize', 1, 'Color', 'b');
            end

            % Tracer les centroids de Cellpose en bleu
            for ncell = 1:length(cellpose_props)
                centroid_cellpose = cellpose_props(ncell).Centroid;
                plot(centroid_cellpose(1), centroid_cellpose(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'b');
            end

            % Marquer les cellules avec IoU ≤ 3 pixels en rouge (Cellpose)
            % for pair_idx = 1:length(cellpose_idx)
            %     cellpose_centroid = cellpose_centroids(cellpose_idx(pair_idx), :);
            %     viscircles(cellpose_centroid, 3, 'Color', 'r', 'LineWidth', 1); % Cercle rouge autour du centroid
            % end

            % Titre et ajustement des axes
            title('Cellpose sur aligned_image');
            xlabel('X Coordinate');
            ylabel('Y Coordinate');
            set(gca, 'YDir', 'reverse'); % Inverser l'axe Y pour un alignement correct
            hold off;

        catch ME
            % Gestion des erreurs
            fprintf('Erreur rencontrée pour le groupe %d : %s\n', m, ME.message);
        end
    end
end
