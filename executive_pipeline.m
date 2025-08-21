%% Preprocessing

clear

% % Définir le chemin vers Python dans l'environnement Suite2p
pyExec = "C:\Users\goldstein\AppData\Local\anaconda3\envs\suite2p\python.exe";
%pyExec = "C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\python.exe"; 

% Initialiser pyenv uniquement s’il n’est pas encore chargé
pe = pyenv;
if pe.Status == "NotLoaded"
    pyenv('Version', pyExec);
    fprintf("pyenv défini sur l’environnement\n");
else

    fprintf("Python déjà chargé depuis : %s\n", pe.Executable);
end

% Chemin où se trouve le fichier python_function.py
new_path = 'D:/local-repo/Python';

%Vérifiez si le chemin est déjà dans le sys.path Python, sinon l'ajouter
if count(py.sys.path, new_path) == 0
    insert(py.sys.path, int32(0), new_path);
end

[animal_date_list, selected_groups] = pipeline_for_data_preprocessing();

env_paths_all = selected_groups.env;
for idx = 1:length(env_paths_all)
    [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(env_paths_all{idx});
    %disp(optical_zoom)
    %disp(position)
end
%%
% Ce que fait cette fonction :
% 1. Demande des choix à l’utilisateur (traiter dossier récent ou non, créer/sélectionner un dossier).
% 2. Prépare la structure selected_groups en ajoutant un champs pour les data (gcamp, mtor, all).
%Pour chaque groupe :
% - Construit les chemins des dossiers selon les dates et canaux (gCamp, rouge, bleu, vert).
% - Crée les dossiers de sortie.
% - Charge ou traite les signaux ΔF/F de GCaMP, les signaux ΔF/F des cellules bleues et non bleues séparément, et les signaux combinés.
% - Sauvegarde des images moyennes et calcule l’énergie de mouvement à partir des vidéos.
% Génère les raster plots et sauve
% garde toutes les données traitées dans selected_groups.

%check_data = input('Do you want to check your data? (1/2): ', 's');
check_data = 2;

[selected_groups, daytime] = process_selected_group(selected_groups, check_data);

%% Processing and analysis

% Ce que fait cette fonction
%Demande quels types d’analyses effectuer :
% - Mesures globales de l’activité : Temps d’enregistrement, fréquence moyenne, etc., sur les données GCaMP (et éventuellement mTOR si include_blue_cells=1).
% - Analyse des SCEs
% - Analyse des clusters
%  Corrélations par paires (pairwise correlations)
% Charge ou calcule les données nécessaires (masques, SCEs, clusters, corrélations).
% Produit et sauvegarde les résultats (fichiers .mat).


% % Ask for analysis types, multiple choices separated by spaces
% analysis_choices_str = input('Choose analysis types (separated by spaces): pairwise correlations (1), SCEs (2), global measures of activity (3), clusters analysis (4)? ', 's');
% 
% % Convert the string of choices into an array of numbers
% analysis_choices = str2num(analysis_choices_str); %#ok<ST2NM>

analysis_choices = [1 2];

selected_groups = pipeline_for_data_processing(selected_groups, analysis_choices);

%%
create_ppt_from_figs(selected_groups, daytime)
