function plot_threshold_sce_evolution2(gcamp_mask, all_DF, all_MAct, fractions, sce_n_cells_threshold, num_samples, field_width_microm, synchronous_frames, MinPeakDistance, MinPeakDistancesce, directories)
    % Fonction pour visualiser l'évolution des seuils et du nombre de SCEs en fonction de la taille du champ

    % Initialiser les variables pour stocker les résultats
    numFolders = length(directories);
    avg_thresholds = cell(numFolders, 1);
    num_sces_all = cell(numFolders, 1);
    avg_num_sces = cell(numFolders, 1);
    areas_microm2 = cell(numFolders, 1);
    num_cells_fractions_all = cell(numFolders, 1);

    %sce_n_cells_threshold = all_data.sce_n_cells_threshold ;
    %TRace = all_data.TRace;

    % Préparer les données à passer aux workers
    data_slices = cell(numFolders, 1);
    for k = 1:numFolders
        DF = all_DF{k};
        gcamp_mask_k = gcamp_mask{k};
        %sce_n_cells_threshold_k = sce_n_cells_threshold{k};
        %TRace_k = TRace{k};
        MAct_k = all_MAct{k};
        
        % Assurer que gcamp_mask est une matrice
        if iscell(gcamp_mask_k)
            gcamp_mask_k = cell2mat(gcamp_mask_k);
        end
        
        % Créer un tableau structuré avec les données à passer
        data_slices{k} = struct('DF', DF, 'gcamp_mask', gcamp_mask_k, 'sce_n_cells_threshold_full', sce_n_cells_threshold, 'MAct_full', MAct_k); % sce_n_cells_threshold_k, 'TRace_full', TRace_k, 
    end

    % Utiliser parfor pour paralléliser le calcul sur les fractions
    parfor k = 1:numFolders
        % Extraire les informations pour le dossier courant
        data = data_slices{k};
        DF = data.DF;
        gcamp_mask = data.gcamp_mask;
        %sce_n_cells_threshold_full = data.sce_n_cells_threshold_full;
        %TRace_full = data.TRace_full;
        MAct_full = data.MAct_full;
        
        % Extraire les dimensions de gcamp_mask
        [NCell, imgHeight, imgWidth] = size(gcamp_mask);
        
        % Calculer la taille du pixel en micromètres
        pixel_size_microm = field_width_microm / imgWidth;
        
        % Initialiser les variables pour stocker les seuils et les SCEs pour chaque taille de champ
        %thresholds_local = cell(length(fractions), 1);
        num_sces_local = cell(length(fractions), 1);
        num_cells_fraction_local = cell(length(fractions), 1);

        % Boucle sur les fractions
        for f = 1:length(fractions)
            fraction = fractions(f);
            
            % Si la fraction est 1, un seul échantillon sera traité
            if fraction == 1
                % Calculer directement pour le champ complet (1 seul échantillon)
                [num_cells_fraction, ~] = size(DF);
                
                [~, TRace_full] = findpeaks(MAct_full(:), 'MinPeakHeight', sce_n_cells_threshold, 'MinPeakDistance', MinPeakDistancesce);

                %threshold_full = sce_n_cells_threshold_1; % Calculer le seuil pour le seul échantillon
                num_sces_full = length(TRace_full);
                % 
                % % Stocker les résultats pour la fraction 1
                % %thresholds_local{f} = threshold_1;
                num_sces_local{f} = num_sces_full;
                num_cells_fraction_local{f} = num_cells_fraction; % Un seul échantillon

                % Calculer la taille en micromètres carrés pour la fraction 1
                areas_microm2{k}(f) = pixel_size_microm^2 * imgHeight * imgWidth;

            else
                % Pour les fractions < 1, traiter num_samples échantillons
                %temp_thresholds = zeros(num_samples, 1); % Stocker les seuils temporaires
                temp_num_sces = zeros(num_samples, 1);   % Stocker les SCEs temporaires
                temp_num_cells_fraction = zeros(num_samples, 1);
                
                % Initialiser la boucle pour `s`
                for s = 1:num_samples
                    % Calculer le nombre de pixels pour la fraction actuelle
                    imageHeight_fraction = round(imgHeight * fraction);
                    imageWidth_fraction = round(imgWidth * fraction);
                    
                    % Superficie en micromètres carrés
                    %area_microm2 = width_microm * height_microm;
                    
                    % Position aléatoire de la zone (attention à ne pas dépasser les limites de l'image)
                    start_row = randi([1, imgHeight - imageHeight_fraction + 1]);
                    start_col = randi([1, imgWidth - imageWidth_fraction + 1]);
                    
                    % Masque des cellules dans la zone aléatoire
                    filtered_masks = zeros(NCell, imageHeight_fraction, imageWidth_fraction);
                    
                    for n = 1:NCell
                        % Extraire le masque de cette cellule
                        current_mask = squeeze(gcamp_mask(n, :, :));
                        
                        % Extraire la sous-région du masque
                        if start_row + imageHeight_fraction - 1 <= size(current_mask, 1) && ...
                           start_col + imageWidth_fraction - 1 <= size(current_mask, 2)
                            filtered_masks(n, :, :) = current_mask(start_row:start_row + imageHeight_fraction - 1, ...
                                                                   start_col:start_col + imageWidth_fraction - 1);
                        else
                            filtered_masks(n, :, :) = zeros(imageHeight_fraction, imageWidth_fraction);
                        end
                    end
                    
                    % Vérifier quelles cellules sont présentes dans la zone aléatoire
                    cells_in_fraction = any(filtered_masks, [2 3]);
                    
                    % Extraire les indices des cellules actives dans la zone
                    active_cells_indices = find(cells_in_fraction);
                    
                    if ~isempty(active_cells_indices)
                        % Extraire les DF des cellules actives dans cette fraction
                        DF_fraction = DF(active_cells_indices, :);
                        [num_cells_fraction, ~] = size(DF_fraction);
    
                        temp_num_cells_fraction(s) = num_cells_fraction;
    
                        % Recalculer Raster et MAct pour cette fraction
                        [~, MAct_subset] = Sumactivity(DF_fraction, MinPeakDistance, synchronous_frames);
    
                        % Shuffling pour trouver le seuil de détection des SCEs
                        % Sumactsh = zeros(Nz - synchronous_frames, NShfl);
                        % for n = 1:NShfl
                        %     Rastersh = Raster_subset;
                        %     for c = 1:num_cells_fraction
                        %         k_shift = randi(Nz - synchronous_frames);
                        %         Rastersh(c,:) = circshift(Rastersh(c,:), k_shift, 2);
                        %     end
                        % 
                        %     MActsh = zeros(1, Nz - synchronous_frames);
                        %     for i = 1:(Nz - synchronous_frames)
                        %         MActsh(i) = sum(max(Rastersh(:,i:i+synchronous_frames), [], 2));
                        %     end
                        % 
                        %     Sumactsh(:, n) = MActsh;
                        % end
                        % 
                        % percentile = 99; % 99th percentile for threshold
                        % temp_thresholds(s) = prctile(Sumactsh(:), percentile);
                        % sce_n_cells_threshold = temp_thresholds(s);

                        % Detect SCEs with the calculated threshold
                        [~, TRace] = findpeaks(MAct_subset(:), 'MinPeakHeight', sce_n_cells_threshold, 'MinPeakDistance', MinPeakDistancesce);
                        temp_num_sces(s) = length(TRace);
                    end
                end
    
                % Stocker les résultats temporaires dans les variables principales
                %thresholds_local{f} = temp_thresholds;
                num_sces_local{f} = temp_num_sces;
                num_cells_fraction_local{f} = temp_num_cells_fraction;
                
                % Calculer la taille en micromètres carrés pour la fraction actuelle
                areas_microm2{k}(f) = pixel_size_microm^2 * (round(imgHeight * fraction) * round(imgWidth * fraction));
            end
            num_sces_all{k}{f} = num_sces_local{f};
            num_cells_fractions_all{k}{f} = num_cells_fraction_local{f};
        end
    
        % Calculer la moyenne des seuils et du nombre de SCEs pour chaque fraction, sauf si la fraction est 1
        %avg_thresholds{k} = zeros(1, length(fractions));
        avg_num_sces{k} = zeros(1, length(fractions));
        
        for f = 1:length(fractions)
            if fractions(f) == 1
                % Pour la fraction 1, utiliser les valeurs directement
                %avg_thresholds{k}(f) = thresholds_local{f};
                avg_num_sces{k}(f) = num_sces_local{f};
            else
                % Calculer la moyenne pour les autres fractions
                %avg_thresholds{k}(f) = mean(thresholds_local{f});
                avg_num_sces{k}(f) = mean(num_sces_local{f});
            end
        end
    end

    % Sauvegarder les résultats
    for k = 1:numFolders
        %avg_thresholds_k = avg_thresholds{k};
        num_sces_local_k = num_sces_all{k};
        avg_num_sces_k = avg_num_sces{k};
        areas_microm2_k = areas_microm2{k};
        num_cells_fraction_k = num_cells_fractions_all{k};
        
        save(fullfile(directories{k}, 'SCEs_evolution.mat'), 'num_cells_fraction_k', 'num_sces_local_k', 'avg_num_sces_k', 'areas_microm2_k');

        % animal_part = animal_date_list{k,3};
        % date_part = animal_date_list{k,4};
        % % 
        % % Plot les résultats
        % figure;
        % hold on;
        % 
        % % Plot thresholds sur l'axe y gauche
        % yyaxis left;
        % plot(areas_microm2_k, avg_thresholds_k, 'b-o', 'LineWidth', 2); % Utiliser areas_microm2_k
        % ylabel('Threshold for SCE Detection');
        % xlabel('Area (μm^2)'); % Mettre à jour le label de l'axe des x
        % title(sprintf('SCE Detection Thresholds and Counts - %s %s', animal_part, date_part));
        % xlim([0 max(areas_microm2_k)]); % Ajuster l'axe x pour aller de 0 à max(areas_microm2_k)
        % ylim([0 max(avg_thresholds_k) * 1.1]); % Ajuster la limite de l'axe y pour les seuils
        % grid on;
        % 
        % % Créer un second axe y pour le nombre de SCEs
        % yyaxis right;
        % plot(areas_microm2_k, avg_num_sces_k, 'r-o', 'LineWidth', 2); % Utiliser areas_microm2_k
        % ylabel('Number of SCEs');
        % 
        % % Ajuster la limite de l'axe y pour le nombre de SCEs
        % max_sces = max(avg_num_sces_k);
        % ylim([0 max_sces * 1.1]); % Ajuster la limite de l'axe y pour le nombre de SCEs
        % 
        % % Ajouter une légende sur le côté
        % legend('Detection Thresholds', 'Number of SCEs', 'Location', 'best');
        % hold off;
        % 
        % % Save the figure
        % fig_name = sprintf('SCE Detection as a function of field size (%s %s)', animal_part, date_part);
        % save_path = fullfile(directories{k}, [fig_name, '.png']);
        % saveas(gcf, save_path);
        % close(gcf);
    end
end
