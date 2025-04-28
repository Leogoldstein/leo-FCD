function [NCell_all, mean_frequency_per_minute_all, std_frequency_per_minute_all, cell_density_per_microm2_all] = basic_metrics(all_DF, all_Raster, all_MAct, date_group_paths, all_sampling_rate)

    % Initialisation des variables pour stocker les résultats
    NCell_all = zeros(length(date_group_paths), 1);
    mean_frequency_per_minute_all = zeros(length(date_group_paths), 1);
    std_frequency_per_minute_all = zeros(length(date_group_paths), 1);
    cell_density_per_microm2_all = zeros(length(date_group_paths), 1);

    for m = 1:length(date_group_paths)
        try
            % Extraction des données pour le groupe m
            DF = all_DF{m};
            Raster = all_Raster{m};
            MAct = all_MAct{m};
            sampling_rate = all_sampling_rate{m};  % Taux d'échantillonnage en Hz

            % Vérification des dimensions entre DF et Raster
            if size(DF, 1) ~= size(Raster, 1)
                warning('Mismatch in the number of neurons between DF and Raster for group %d. Adjusting to the smallest size.', m);
                min_cells = min(size(DF, 1), size(Raster, 1));
                DF = DF(1:min_cells, :);
                Raster = Raster(1:min_cells, :);
            end

            if size(DF, 2) ~= size(Raster, 2)
                warning('Mismatch in the number of frames between DF and Raster for group %d. Adjusting to the smallest size.', m);
                min_frames = min(size(DF, 2), size(Raster, 2));
                DF = DF(:, 1:min_frames);
                Raster = Raster(:, 1:min_frames);
            end

            % Dimensions de Raster
            [num_cells, Nframes] = size(Raster);
            NCell_all(m) = num_cells;  % Nombre de neurones dans le groupe

            % Fréquence d'activité par minute pour chaque neurone
            mean_activity = mean(Raster, 2);  % Moyenne d'activité pour chaque neurone
            frequency_per_minute = mean_activity * sampling_rate * 60;  % Fréquence en activité par minute

            % Moyenne et écart-type des fréquences pour ce groupe
            mean_frequency_per_minute_all(m) = mean(frequency_per_minute, 'omitnan');  % Moyenne des fréquences
            std_frequency_per_minute_all(m) = std(frequency_per_minute, 'omitnan');   % Écart-type des fréquences
            
            % % Densité cellulaire
            % imgHeight = all_imageHeight{m};
            % imgWidth = all_imageWidth{m};
            % 
            % % Largeur du champ en micromètres
            % field_width_microm = 750;
            % 
            % % Calculer la taille du pixel en micromètres
            % pixel_size_microm = field_width_microm / imgWidth;
            % 
            % % Calculer l'aire totale de l'image en micromètres carrés
            % areas_microm2 = pixel_size_microm^2 * imgHeight * imgWidth;
            % 
            % % Calculer la densité cellulaire (NCell / aire en micromètres carrés)
            % cell_density_per_microm2_all(m) = num_cells / areas_microm2;        

        catch ME
            % Afficher un message d'erreur en cas de problème
            fprintf('Error processing group %d: %s\n', m, ME.message);
            disp(getReport(ME, 'extended'));
        end
    end

    % Retourner les résultats calculés
    return;
end
