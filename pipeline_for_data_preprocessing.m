function [truedataFolders, animal_date_list] = pipeline_for_data_preprocessing()
    % pipeline_for_data_preprocessing : Fonction pour traiter les données
    % selon le choix de l'utilisateur.
    %
    % Choix possibles :
    % 1 : JM (Jure's data avec fichiers .npy)
    % 2 : FCD (données Fall.mat pour FCD)
    % 3 : CTRL (données Fall.mat pour CTRL)
    %
    % Sorties :
    % - truedataFolders : Dossiers des données valides
    % - animal_date_list : Liste des animaux et dates
    % - F : Données brutes
    % - DF : Données dF/F
    % - ops : Paramètres d'opérations
    % - stat : Données statistiques
    % - iscell : Indicateurs de cellules

    % Définir les chemins de base
    jm_folder = '\\10.51.106.5\data\Data\jm\'; % Dossiers pour JM
    destinationFolder = 'D:/imaging/jm/'; % Destination des fichiers JM
    fcd_folder = 'D:\imaging\FCD'; % Dossiers pour FCD
    ctrl_folder = 'D:\imaging\CTRL'; % Dossiers pour CTRL

    % Initialisation des sorties
    truedataFolders = [];
    animal_date_list = [];

    % Demander à l'utilisateur de choisir un dossier
    disp('Veuillez choisir un dossier à traiter :');
    disp('1 : JM (Jure''s data)');
    disp('2 : FCD (Fall.mat data)');
    disp('3 : CTRL (Fall.mat data)');
    choice = input('Entrez le numéro de votre choix (1, 2 ou 3) : ');

    % Traitement selon le choix
    switch choice
        case 1
            % Traitement JM (Jure's data)
            disp('Traitement des données JM...');
            dataFolders = select_folders(jm_folder);
            [statPaths, FPaths, iscellPaths, opsPaths, ~] = find_npy_folders(dataFolders);
            [newFPaths, newStatPaths, newIscellPaths, newOpsPaths, truedataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, destinationFolder);
            disp('Traitement JM terminé.');

        case 2
            % Traitement FCD
            disp('Traitement des données FCD...');
            initial_folder = fcd_folder; % Point de départ pour la sélection
            dataFolders = select_folders(initial_folder);
            [truedataFolders, ~] = find_Fall_folders(dataFolders); % Identifier les fichiers Fall.mat
            disp('Traitement FCD terminé.');

        case 3
            % Traitement CTRL
            disp('Traitement des données CTRL...');
            initial_folder = ctrl_folder; % Point de départ pour la sélection
            dataFolders = select_folders(initial_folder);
            [truedataFolders, ~] = find_Fall_folders(dataFolders); % Identifier les fichiers Fall.mat
            disp('Traitement CTRL terminé.');

        otherwise
            % Option invalide
            error('Choix invalide. Veuillez relancer la fonction et choisir 1, 2 ou 3.');
    end

    % Créer une liste des animaux et des dates
    animal_date_list = create_animal_date_list(truedataFolders);

    % Associer les âges aux animaux
    animal_date_list = assign_age_to_animals(animal_date_list);
end