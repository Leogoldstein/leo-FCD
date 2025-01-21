function iou_results = compute_iou_between_centroids(all_gcamp_props, all_props_cellpose, date_group_paths, tolerance_radius)
    % compute_iou_between_centroids : Calcule l'IoU entre les centroïdes de deux ensembles de propriétés de cellules.
    %
    % Entrées :
    %   - all_gcamp_props : Cell array contenant les propriétés GCaMP pour chaque groupe.
    %   - all_props_cellpose : Cell array contenant les propriétés Cellpose pour chaque groupe.
    %   - date_group_paths : Cell array des chemins des groupes (pour la boucle).
    %   - tolerance_radius : Rayon de tolérance pour considérer deux centroïdes comme correspondants.
    %
    % Sortie :
    %   - iou_results : Cell array contenant les matrices IoU pour chaque groupe.

    % Initialiser les résultats de l'IoU
    iou_results = cell(length(date_group_paths), 1);

    for m = 1:length(date_group_paths)
        try
            % Extraction des données pour le groupe m
            gcamp_props = all_gcamp_props{m};
            cellpose_props = all_props_cellpose{m};

            % Initialisation pour stocker les IoU pour chaque cellule
            group_iou = zeros(length(gcamp_props), length(cellpose_props));

            % Boucle sur les cellules GCaMP
            for i = 1:length(gcamp_props)
                % Obtenir le centroïde de la cellule GCaMP
                gcamp_centroid = gcamp_props(i).Centroid;

                % Boucle sur les cellules Cellpose
                for j = 1:length(cellpose_props)
                    % Obtenir le centroïde de la cellule Cellpose
                    cellpose_centroid = cellpose_props(j).Centroid;

                    % Calcul de la distance entre les deux centroïdes
                    distance = sqrt((gcamp_centroid(1) - cellpose_centroid(1))^2 + ...
                                    (gcamp_centroid(2) - cellpose_centroid(2))^2);

                    % Vérifier si la distance est inférieure au rayon de tolérance
                    if distance <= tolerance_radius
                        % Intersection (distance inférieure au rayon) / Union (aire des deux cellules)
                        intersection = min(gcamp_props(i).Area, cellpose_props(j).Area);
                        union = gcamp_props(i).Area + cellpose_props(j).Area - intersection;

                        % Calcul de l'IoU
                        group_iou(i, j) = intersection / union;
                    else
                        % Si la distance est trop grande, l'IoU est nul
                        group_iou(i, j) = 0;
                    end
                end
            end

            % Stocker les résultats de l'IoU pour le groupe m
            iou_results{m} = group_iou;

        catch ME
            % Gestion des erreurs
            fprintf('Erreur dans le groupe %d : %s\n', m, ME.message);
        end
    end

    % Affichage des résultats
    for m = 1:length(iou_results)
        fprintf('Résultats IoU pour le groupe %d :\n', m);
        disp(iou_results{m});
    end
end
