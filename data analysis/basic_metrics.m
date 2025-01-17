function [NCell_all, mean_frequency_per_minute_all, std_frequency_per_minute_all, cell_density_per_microm2_all, mean_max_corr_all] = basic_metrics(all_DF, all_Raster, all_MAct, date_group_paths, all_sampling_rate, all_imageHeight, all_imageWidth)

    % Initialisation des variables pour stocker les résultats
    NCell_all = zeros(length(date_group_paths), 1);
    mean_frequency_per_minute_all = zeros(length(date_group_paths), 1);
    std_frequency_per_minute_all = zeros(length(date_group_paths), 1);
    mean_max_corr_all = zeros(length(date_group_paths), 1);
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
            
            % Densité cellulaire
            imgHeight = all_imageHeight{m};
            imgWidth = all_imageWidth{m};

            % Largeur du champ en micromètres
            field_width_microm = 750;

            % Calculer la taille du pixel en micromètres
            pixel_size_microm = field_width_microm / imgWidth;
            
            % Calculer l'aire totale de l'image en micromètres carrés
            areas_microm2 = pixel_size_microm^2 * imgHeight * imgWidth;

            % Calculer la densité cellulaire (NCell / aire en micromètres carrés)
            cell_density_per_microm2_all(m) = num_cells / areas_microm2;
            
            % % Création d'une figure pour ce groupe
            % figure;
            % screen_size = get(0, 'ScreenSize');  % Taille de l'écran
            % set(gcf, 'Position', screen_size);   % Ajustement de la figure à la taille de l'écran
            % 
            % % Histogramme des fréquences
            % subplot(3, 1, 1);
            % histogram(frequency_per_minute, 'FaceColor', [0.2, 0.6, 0.8], 'EdgeColor', 'k');
            % title('Distribution des fréquences d’activité (par minute)', 'FontSize', 14);
            % ylabel('Nombre de neurones', 'FontSize', 12);
            % xlabel('Fréquence d’activité (par minute)', 'FontSize', 12);
            % grid on;
            % 
            % % Données brutes des 10 premiers neurones
            % subplot(3, 1, 2);
            % time_minutes = (0:Nframes-1) / sampling_rate / 60;  % Temps en minutes
            % plot(time_minutes, DF(1:min(10, size(DF, 1)), :)');  % Afficher les données des 10 premiers neurones
            % title('Données brutes des 10 premiers neurones', 'FontSize', 14);
            % ylabel('Activité', 'FontSize', 12);
            % xlabel('Temps (minutes)', 'FontSize', 12);
            % xlim([min(time_minutes), max(time_minutes)]);
            % grid on;
            % 
            % % Matrice de corrélation maximale pour les 10 premiers neurones
            % subplot(3, 1, 3);
            % 
            % num_cells_to_analyze = num_cells;
            % max_lag = 100;
            % lag=[-100:-1 1:100];
            % max_corr_values = zeros(num_cells_to_analyze);  % Matrice de corrélations
            % 
            % % Calcul des corrélations entre les paires
            % for i = 1:num_cells_to_analyze
            %     for j = 1:num_cells_to_analyze
            %         [cross_corr, ~] = xcorr(DF(i, :), DF(j, :), max_lag, 'coeff');
            % 
            %         % Find maximum correlation and corresponding lag
            %         [max_corr, idx_max_corr] = max(cross_corr);
            %         %lag_at_max_corr = lags(idx_max_corr);
            % 
            %         % Store results
            %         max_corr_values(i,j) = max_corr;
            %         %lags_at_max_corr(i,j) = lag_at_max_corr;
            % 
            %     end
            % end
            % 
            % % Mettre les valeurs diagonales à NaN pour éviter les corrélations de soi-même
            % max_corr_values(logical(eye(size(max_corr_values)))) = NaN;
            % 
            % % Calculer la moyenne des corrélations hors diagonale
            % mean_max_corr_all(m) = mean(max_corr_values(:), 'omitnan');
            % 
            % % Afficher la matrice de corrélations
            % imagesc(max_corr_values);  % Matrice comme image
            % colorbar;
            % colormap(jet);
            % clim([0, 1]);  % Limiter l'échelle entre 0 et 1
            % title('Max Pairwise Correlation (10 premiers neurones)', 'FontSize', 14);
            % xlabel('Neurones', 'FontSize', 12);
            % ylabel('Neurones', 'FontSize', 12);
            % axis square;

        catch ME
            % Afficher un message d'erreur en cas de problème
            fprintf('Error processing group %d: %s\n', m, ME.message);
            disp(getReport(ME, 'extended'));
        end
    end

    % Retourner les résultats calculés
    return;
end
