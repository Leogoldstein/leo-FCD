%% Preprocessing

% Chemin où se trouve le fichier python_function.py
new_path = 'D:/local-repo/data preprocessing';

%Vérifiez si le chemin est déjà dans le sys.path Python, sinon l'ajouter
if count(py.sys.path, new_path) == 0
    insert(py.sys.path, int32(0), new_path);
end

[animal_date_list, env_paths_all, selected_groups] = pipeline_for_data_preprocessing();

% %
% for idx = 1:length(env_paths_all)
%     [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(env_paths_all{idx});
%     disp(position)
% end
%%
% Processing and analysis
pipeline_for_data_processing(selected_groups)
%%

% Plot the fluorescence values for each cell across images
figure;
hold on;  % Keep all the plots on the same figure

% Loop through each cell and plot its fluorescence values
for n = 1:size(flattened_DF_blue, 1)  % Loop over each cell
    plot(flattened_DF_blue(n, :));  % Plot the DF values for the n-th cell
end

% Customize the plot
xlabel('Image Number');  % X-axis label (image index)
ylabel('Fluorescence Intensity (DF)');  % Y-axis label (DF value)
title('Fluorescence Time Series for Each Cell');  % Plot title
legend(cellstr(num2str((1:size(flattened_DF_blue, 1))')));  % Add a legend for each cell
hold off;  % End the holding of the plot
