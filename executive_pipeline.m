%% Preprocessing

% Chemin où se trouve le fichier python_function.py
new_path = 'D:/local-repo/data preprocessing';

%Vérifiez si le chemin est déjà dans le sys.path Python, sinon l'ajouter
if count(py.sys.path, new_path) == 0
    insert(py.sys.path, int32(0), new_path);
end

[animal_date_list, env_paths_all, selected_groups] = pipeline_for_data_preprocessing();

%%
for idx = 1:length(env_paths_all)
    [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(env_paths_all{idx});
    disp(sampling_rate)

end

%% Processing and analysis

pipeline_for_data_processing(selected_groups)

%%
% Spécifiez le chemin et les dimensions de l'image
path = 'D:\imaging\FCD\mTor17\ani1\2024-12-17\SingleImage-12172024-0832-004blue';
canal = 3;


[mask_cellpose, props_cellpose, outlines_x_cellpose, outlines_y_cellpose] = load_masks_from_cellpose(path, canal);