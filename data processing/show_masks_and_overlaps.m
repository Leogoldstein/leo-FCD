function [matched_gcamp_idx, matched_cellpose_idx] = show_masks_and_overlaps(gcamp_props, cellpose_props, meanImg, aligned_image, outline_gcampx, outline_gcampy, outline_x_cellpose, outline_y_cellpose, R, m)
    try
        % Extraire les centroids sous forme de matrice Nx2
        gcamp_centroids = cat(1, gcamp_props.Centroid); % Nx2
        cellpose_centroids = cat(1, cellpose_props.Centroid); % Mx2

        % Vérifier si les centroids existent
        if isempty(gcamp_centroids) || isempty(cellpose_centroids)
            fprintf('Skipping group %d: No centroids to match.\n', m);
            matched_gcamp_idx = [];
            matched_cellpose_idx = [];
            return;
        end

        % Calculer les distances entre chaque pair de centroids
        D = pdist2(gcamp_centroids, cellpose_centroids);

        % Trouver les centroids qui se chevauchent dans le rayon R
        [matched_gcamp_idx, matched_cellpose_idx] = find(D < R);

        % Calcul de IoU (Intersection over Union)
        intersection = length(unique(matched_gcamp_idx));
        total_gcamp = size(gcamp_centroids, 1);
        total_cellpose = size(cellpose_centroids, 1);
        union = total_gcamp + total_cellpose - intersection;
        IoU = intersection / union;

        % ---- Affichage des figures ----
        figure;

        % ---- Subplot 1: GCaMP sur meanImg ----
        subplot(1, 2, 1);
        hold on;
        imagesc(meanImg);
        colormap gray;
        axis image;

        for ncell = 1:length(outline_gcampx)
            plot(outline_gcampx{ncell}, outline_gcampy{ncell}, '.', 'MarkerSize', 1, 'Color', 'g');
        end

        for ncell = 1:length(gcamp_props)
            plot(gcamp_props(ncell).Centroid(1), gcamp_props(ncell).Centroid(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'g');
        end

        plot(gcamp_centroids(matched_gcamp_idx,1), gcamp_centroids(matched_gcamp_idx,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
        title('GCaMP sur meanImg');
        xlabel('X Coordinate');
        ylabel('Y Coordinate');
        set(gca, 'YDir', 'reverse');
        hold off;

        % ---- Subplot 2: Cellpose sur aligned_image ----
        subplot(1, 2, 2);
        hold on;
        imagesc(aligned_image);
        colormap gray;
        axis image;

        for ncell = 1:length(outline_x_cellpose)
            plot(outline_x_cellpose{ncell}, outline_y_cellpose{ncell}, '.', 'MarkerSize', 1, 'Color', 'b');
        end

        for ncell = 1:length(cellpose_props)
            plot(cellpose_props(ncell).Centroid(1), cellpose_props(ncell).Centroid(2), 'x', 'MarkerSize', 8, 'LineWidth', 2, 'Color', 'b');
        end

        plot(cellpose_centroids(matched_cellpose_idx,1), cellpose_centroids(matched_cellpose_idx,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
        title(sprintf('Cellpose sur aligned_image (IoU: %.4f)', IoU));
        xlabel('X Coordinate');
        ylabel('Y Coordinate');
        set(gca, 'YDir', 'reverse');
        hold off;

        drawnow;
    catch ME
        fprintf('Erreur dans le groupe %d: %s\n', m, ME.message);
        matched_gcamp_idx = [];
        matched_cellpose_idx = [];
    end
end