function plot_DF(all_DF, current_animal_group, current_ages_group, gcamp_output_folders, all_DF_all, all_blue_indices)

    % Vérifie si all_DF est non vide
    if nargin < 5 && ~isempty(all_DF)
      
        % Boucle sur chaque élément de all_DF
        for idx = 1:length(all_DF)

            % Création du chemin pour sauvegarder la figure
            fig_save_path = fullfile(gcamp_output_folders{idx}, sprintf('%s_%s_DF_plot.fig', ...
                strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{idx}, ' ', '_')));

            fig_save_path2 = fullfile(gcamp_output_folders{idx}, sprintf('%s_%s_DF_plot.png', ...
                strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{idx}, ' ', '_')));
            
            if exist(fig_save_path, 'file')
               disp(['Figure already exists and was skipped: ' fig_save_path]);
               continue;
            end

            DF = all_DF{idx};       
            [num_cells, ~] = size(DF);
            
            % Créer une figure pour le tracé
            figure;
            hold on;

            % Initialisation du décalage
            vertical_offset = 0;

            % Tracer chaque cellule avec un décalage basé sur le max du neurone en dessous
            for cell_idx = 1:num_cells
                plot(DF(cell_idx, :) + vertical_offset, '-');      
                
                % Mise à jour du décalage basé sur le max du neurone actuel
                if cell_idx < num_cells
                    vertical_offset = vertical_offset + max(DF(cell_idx, :)) * 1.2;  
                end
            end
            hold off;

            % Ajouter des labels et un titre
            xlabel('Frame Number');
            ylabel('Fluorescence Intensity');
            title(['DF for Animal: ' current_animal_group ...
                   ', Age: ' current_ages_group{idx}]);

            % Sauvegarde de la figure avec try-catch
            try
                saveas(gcf, fig_save_path);
                saveas(gcf, fig_save_path2);
                disp(['DF plots saved in: ' fig_save_path]);
            catch ME
                disp(['Error saving figure: ' fig_save_path]);
                disp(['Error message: ' ME.message]);
            end
            
            close(gcf);
        end

    elseif ~isempty(all_blue_indices)  % Vérifie si all_DF_all est non vide
        for idx = 1:length(all_DF_all)

            % Création du chemin pour sauvegarder la figure
            fig_save_path = fullfile(gcamp_output_folders{idx}, sprintf('%s_%s_DF_plot_mtor.fig', ...
                strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{idx}, ' ', '_')));

            fig_save_path2 = fullfile(gcamp_output_folders{idx}, sprintf('%s_%s_DF_plot_mtor.png', ...
                strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{idx}, ' ', '_')));
            
            if exist(fig_save_path, 'file')
               disp(['Figure already exists and was skipped: ' fig_save_path]);
               continue;
            end

            DF = all_DF_all{idx};
            blue_indices = all_blue_indices{idx};
            
            % Séparer les cellules bleues et les autres cellules
            DF_blue = DF(blue_indices,:);  
            blue_indices_logical = ismember(1:size(DF, 1), blue_indices);
            DF_not_blue = DF(~blue_indices_logical,:); 

            % Création de la figure
            figure;
            hold on;

            % Initialisation du décalage
            vertical_offset = 0;

            % Tracer les cellules bleues en bleu
            for i = 1:size(DF_blue, 1)
                plot(DF_blue(i, :) + vertical_offset, '-', 'Color', 'b', ...
                    'DisplayName', ['Blue Cell ' num2str(blue_indices(i))]);      

                % Mise à jour du décalage basé sur le max du neurone actuel
                if i < size(DF_blue, 1)
                    vertical_offset = vertical_offset + max(DF_blue(i, :)) * 1.2;
                end
            end

            % Tracer les autres cellules en vert
            for j = 1:size(DF_not_blue, 1)
                plot(DF_not_blue(j, :) + vertical_offset, '-', 'Color', 'g', ...
                    'DisplayName', ['Non-Blue Cell ' num2str(j)]);      

                % Mise à jour du décalage basé sur le max du neurone actuel
                if j < size(DF_not_blue, 1)
                    vertical_offset = vertical_offset + max(DF_not_blue(j, :)) * 1.2;
                end
            end

            hold off;

            % Ajouter des labels et un titre
            xlabel('Frame Number');
            ylabel('Fluorescence Intensity');
            title(['DF for Animal: ' current_animal_group ...
                   ', Age: ' current_ages_group{idx}]);
            legend show;

            % Sauvegarde de la figure avec try-catch
            try
                saveas(gcf, fig_save_path);
                saveas(gcf, fig_save_path2);
                disp(['DF plots saved in: ' fig_save_path]);
            catch ME
                disp(['Error saving figure: ' fig_save_path]);
                disp(['Error message: ' ME.message]);
            end
            
            close(gcf);
        end
    end
end
