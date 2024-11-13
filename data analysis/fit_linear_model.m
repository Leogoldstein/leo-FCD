function fit_linear_model(directories, all_data, animal_date_list)
    % Fonction pour ajuster un modèle linéaire aux données SCEs en fonction
    % de la fraction de la taille de l'image, du nombre de neurones et de l'âge
    %
    % Inputs:
    %   directories - Liste des dossiers pour chaque animal
    %   all_data - Structure contenant les champs suivants :
    %       field_size_fraction - Fraction de la taille de l'image
    %       num_SCEs_image - Nombre de SCEs en fonction de la taille de l'image
    %       num_cells_fraction - Fraction du nombre de neurones
    %       num_SCEs_neurons - Nombre de SCEs en fonction du nombre de neurones

    % Initialiser des tableaux pour stocker les données concaténées
    all_field_size_fraction = [];
    all_num_neurons = [];
    all_num_SCEs = [];
    all_ages = [];

    % Itérer sur chaque ensemble de données (un par dossier/animal)
    for k = 1:length(directories)
        % Extraire les données pour le dossier courant
        field_size_fraction = all_data.field_size_fraction{k}; % Taille de champ pour chaque fraction
        num_neurons = all_data.num_cells_fraction{k};          % Nombre de neurones pour chaque fraction
        num_SCEs = all_data.num_SCEs{k};                       % Nombre de SCEs pour chaque fraction
        current_age = animal_date_list(k,3);                                 % Age correspondant à ce directory (valeur numérique)

        % Concaténer les données pour chaque animal dans des colonnes
        for f = 1:length(field_size_fraction)
            % Extraire les SCEs et les neurones pour chaque fraction
            current_num_SCEs = num_SCEs{f}; % Garder une référence au tableau original
            current_num_neurons = num_neurons{f}; % Garder une référence au tableau original

            % Vérifier si les longueurs des tableaux sont les mêmes
            if length(current_num_SCEs) ~= length(current_num_neurons)
                disp(['Error: Inconsistent data length for fraction ', num2str(f)]);
                continue; % Passer à la prochaine fraction si les longueurs sont différentes
            end

            % Concaténer les données de cette fraction
            all_num_SCEs = [all_num_SCEs; current_num_SCEs(:)];
            all_num_neurons = [all_num_neurons; current_num_neurons(:)];
            all_field_size_fraction = [all_field_size_fraction; repmat(field_size_fraction(f), length(current_num_SCEs), 1)];
            all_ages = [all_ages; repmat(current_age, length(current_num_SCEs), 1)];
        end
    end

    % Conversion de 'all_ages' en variable catégorielle
    all_ages = categorical(all_ages);

    % Convertir les variables en double pour s'assurer qu'elles sont bien numériques
    all_field_size_fraction = double(all_field_size_fraction);
    all_num_neurons = double(all_num_neurons);
    all_num_SCEs = double(all_num_SCEs);

    % Créer une table à partir des données concaténées, incluant l'âge
    tbl = table(all_field_size_fraction, all_num_neurons, all_num_SCEs, all_ages, ...
        'VariableNames', {'Field_Size_Fraction', 'Number_of_Neurons', 'Number_of_SCEs', 'Age'});

    % Vérifier les types de données dans la table
    disp('Vérification des types de données dans la table:');
    disp(varfun(@class, tbl, 'OutputFormat', 'table'));

    % Afficher la table pour vérification
    disp('Affichage de la table créée:');
    disp(tbl);

    % Ajuster un modèle linéaire avec interactions, en incluant l'âge comme facteur catégoriel
    try
        mdl = fitlm(tbl, 'Number_of_SCEs ~ 1 + Field_Size_Fraction * Number_of_Neurons + Age');
    catch ME
        disp('Erreur lors de l''ajustement du modèle :');
        disp(ME.message);
        return;
    end

    % Afficher les résultats du modèle
    disp(mdl);

    % Visualiser les résultats avec plotSlice
    figure;
    plotSlice(mdl);

    %plotEffects(mdl)
    %plotInteraction(mdl,'Field_Size_Fraction','Number_of_Neurons','predictions')

    animal_part = animal_date_list{1, 1}; % Assuming the same animal part for all directories
    fig_name = sprintf('Linear regression analysis of %s', animal_part);

    % Save the figure to the specified destination folder
    PathSave = fullfile('D:', 'after_processing', 'Synchrony peaks', animal_part);
    
    savefig(fullfile(PathSave, [fig_name, '.fig'])); % Sauvegarde de la figure interactive

    % Vous pouvez également sauvegarder au format .mat si vous souhaitez enregistrer le modèle
    save(fullfile(PathSave, [fig_name, '_model.mat']), 'mdl');

    close(gcf);
    
end
