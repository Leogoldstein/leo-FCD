function plot_pairwise_corr(current_ages_group, all_max_corr_gcamp_gcamp, current_ani_path_group, animal_name)
    % Déclarations
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    corrTypeLabel = 'gcamp-gcamp';  % Corrélation fixe ici
    animal_data = [];
    animal_age = [];

    % Conversion des âges
    current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
    [~, x_indices] = ismember(current_ages, age_values);

    % Récupération des corrélations pour chaque session
    for sessionIdx = 1:length(current_ages_group)
        ageIdx = x_indices(sessionIdx);
        if sessionIdx <= numel(all_max_corr_gcamp_gcamp) && ~isempty(all_max_corr_gcamp_gcamp{sessionIdx})
            current_corrs = all_max_corr_gcamp_gcamp{sessionIdx}(:);
            animal_data = [animal_data; current_corrs];
            animal_age = [animal_age; repmat(age_labels(ageIdx), length(current_corrs), 1)];
        end
    end

    if ~isempty(animal_data)
        % Identifier les âges effectivement présents
        unique_ages_used = unique(animal_age, 'stable');
        
        % Créer des catégories uniquement pour les âges présents
        ordered_animal_age = categorical(animal_age, unique_ages_used, 'Ordinal', true);
    
        [~, sortIdx] = sort(ordered_animal_age);
        sorted_data = animal_data(sortIdx);
        sorted_age = ordered_animal_age(sortIdx);
    
        figure('Name', sprintf('%s - %s', animal_name, corrTypeLabel), 'Position', [100, 100, 1200, 600]);
        violinplot(sorted_data, sorted_age);
        ylabel('Pairwise correlation');
        title(sprintf('%s - %s - %s', animal_name, corrTypeLabel));
        xticklabels(unique_ages_used);  % <- Met à jour les labels visibles
    
        % Sauvegarde
        file_name = sprintf('Corr_%s_%s_%s.png', animal_name, corrTypeLabel);
        save_path = fullfile(current_ani_path_group, file_name);
        saveas(gcf, save_path, 'png');
        close(gcf);
    else
        warning('Aucune donnée disponible pour %s.', animal_name);
    end

end