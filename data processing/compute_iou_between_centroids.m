function compute_iou_between_centroids(all_gcamp_props, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose, all_outline_gcampx, all_outline_gcampy, date_group_paths, all_ops)
    for m = 1:length(date_group_paths)
        try
            % Extraction des données pour le groupe m
            gcamp_props = all_gcamp_props{m};
            cellpose_props = all_props_cellpose{m};

            % Gestion de l'image de fond (meanImg)
            if isa(all_ops{m}, 'py.dict')
                ops = all_ops{m}; % Python dictionary
                meanImg = double(ops{'meanImg'}); % Convertir en tableau MATLAB
            else
                ops = all_ops{m}; % Structure MATLAB
                meanImg = ops.meanImg;
            end

            % Créer une nouvelle figure pour chaque groupe
            figure;
            hold on;

            % Afficher l'image de fond (meanImg)
            imagesc(meanImg);
            colormap gray;
            axis image;

            % Tracer les outlines de Cellpose en bleu
            for ncell = 1:length(all_outlines_x_cellpose{m})
                pixels_x = all_outlines_x_cellpose{m}{ncell};
                pixels_y = all_outlines_y_cellpose{m}{ncell};
                plot(pixels_x, pixels_y, '.', 'MarkerSize', 1, 'Color', 'b');
            end

            % Tracer les outlines de GCaMP en vert
            for ncell = 1:length(all_outline_gcampx{m})
                pixels_x_gcamp = all_outline_gcampx{m}{ncell};
                pixels_y_gcamp = all_outline_gcampy{m}{ncell};
                plot(pixels_x_gcamp, pixels_y_gcamp, '.', 'MarkerSize', 1, 'Color', 'g');
            end

            % Tracer les centroids de Cellpose en bleu
            for ncell = 1:length(cellpose_props)
                centroid_cellpose = cellpose_props(ncell).Centroid;
                plot(centroid_cellpose(1), centroid_cellpose(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'b');
            end

            % Tracer les centroids de GCaMP en vert
            for ncell = 1:length(gcamp_props)
                centroid_gcamp = gcamp_props(ncell).Centroid;
                plot(centroid_gcamp(1), centroid_gcamp(2), 'o', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'g');
            end

            % Ajouter des titres et ajustements de l'axe
            title(['Superposition des outlines et centroids pour le groupe ', num2str(m)]);
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
