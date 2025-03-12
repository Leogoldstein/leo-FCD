function plot_cell_traces(all_DF, all_isort1, animal_date_list, directories, startIndex)
    % plot_cell_traces Trace les activités des cellules triées par indice et
    % les visualise avec des décalages verticaux pour éviter les chevauchements.
    %
    % Inputs:
    % - all_DF : Cell array contenant les données d'activité des cellules
    % - all_isort1 : Cell array contenant les indices triés des cellules
    % - animal_date_list : Cell array contenant les informations sur les animaux et les dates
    % - directories : Cell array des répertoires pour sauvegarder les figures
    % - startIndex : L'indice à partir duquel les cellules doivent être tracées
    %
    % La fonction vérifie la validité des données et trace les activités des cellules
    % dans des figures séparées pour chaque jeu de données.

    % Boucle sur les répertoires
    for k = 1:length(directories)
        try
            % Extraire les données des cellules
            DF = all_DF{k};
            isort1 = all_isort1{k};
            animal_part = animal_date_list{k, 1};
            date_part = animal_date_list{k, 2};
            
            % Vérifier la taille de DF et isort1
            if isempty(isort1) || isempty(DF)
                disp(['Données manquantes pour l''index ' num2str(k)]);
                continue; % Passer à l'itération suivante si les données sont manquantes
            end
            
            % Vérifier que isort1 contient suffisamment d'indices
            if length(isort1) < startIndex
                disp(['Pas assez d''indices dans isort1 pour l''index ' num2str(k)]);
                continue;
            end
            
            % Obtenir les indices à partir de isort1 et les trier en ordre décroissant
            indicesToPlot = sort(isort1(startIndex:end), 'descend');
            
            % Vérifier que les indices sont valides pour DF
            if any(indicesToPlot > size(DF, 1))
                disp(['Certains indices sont hors limites pour DF à l''index ' num2str(k)]);
                continue;
            end
            
            % Créer une nouvelle figure
            figure;
            hold on; % Garder le même graphique pour tous les tracés
            
            % Initialiser la variable pour le maximum du décalage vertical
            maxVerticalOffset = 0;
            
            % Tracer les données pour chaque cellule
            for i = 1:length(indicesToPlot)
                cellIndex = indicesToPlot(i);
                
                % Calculer le décalage vertical pour éviter les chevauchements
                verticalOffset = (i - 1) * 20; % Augmenter l'espace entre les tracés
                maxVerticalOffset = max(maxVerticalOffset, verticalOffset); % Mettre à jour le maximum du décalage vertical
                
                % Tracer les données de la cellule avec un décalage vertical
                plot(DF(cellIndex, :) + verticalOffset);
                
                % Ajouter le numéro de cellule sur l'axe des y
                text(1, verticalOffset, num2str(cellIndex), 'VerticalAlignment', 'bottom', ...
                    'HorizontalAlignment', 'right', 'FontSize', 8, 'Color', 'black');
            end
            
            % Ajuster les propriétés du graphique
            xlabel('Frames');
            title(sprintf('Tracés des cellules %d à %d pour %s (%s)', startIndex, length(isort1), animal_part, date_part));
            xlim([1 size(DF, 2)]); % Limiter l'axe des x à la dernière frame
            ylim([-30 maxVerticalOffset + 30]); % Limiter l'axe des y au décalage vertical après le tracé le plus haut
            
            % Masquer les ticks et labels de l'axe des y
            set(gca, 'YTick', []); % Enlever les ticks de l'axe des y
            set(gca, 'YTickLabel', []); % Enlever les labels de l'axe des y
            
            % Supprimer la légende si elle est présente
            if isfield(gca, 'Legend')
                legend off;
            end
            
            % Afficher la grille
            grid on;
            
            hold off; % Arrêter d'ajouter au même graphique
            
        catch ME
            disp(['Erreur lors du traitement du dossier ' num2str(k) ': ' ME.message]);
        end
    end
end
