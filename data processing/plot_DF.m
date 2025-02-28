function plot_DF(all_DF)
    % Loop over each element in all_DF
    for idx = 1:length(all_DF)
        % Extract DF_blue for the current path
        DF_blue = all_DF{idx};       
        if ~ismissing(DF_blue)
            % Number of frames (assuming rows are cells and columns are frames)
            [num_cells, ~] = size(DF_blue);
    
            % Create a figure for plotting
            figure;
    
            % Plot each cell's DF_blue (each row represents a cell)
            hold on;
            for cell_idx = 1:num_cells
                plot(DF_blue(cell_idx, :), 'DisplayName', ['Cell ' num2str(cell_idx)]);
            end
            hold off;
    
            % Add labels and title
            xlabel('Frame Number');
            ylabel('Fluorescence Intensity');
            title(['DF_blue for Group ' num2str(idx)]);
            legend show; % Show legend for each cell
        end
    end
end
