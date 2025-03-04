function DF = DF_processing(DF)
    % Apply preprocessing steps to the data matrix DF.
    % Input:
    % - DF: Data matrix to be preprocessed.
    % Output:
    % - DF: Preprocessed data matrix.
    
    % Savitzky-Golay filter
    DF = sgolayfilt(DF', 3, 5)' ;

    [NCell, Nz] = size(DF);

    window_size = 2000; % Largeur de la fenêtre en points temporels
    percentile_value=5;
    num_blocks = ceil(Nz / window_size);
    for n=1:NCell
        trace=DF(n,:);
        F0 = nan(Nz, 1);
        % Calcul du percentile bloc par bloc
        for i = 1:num_blocks
            start_idx = (i-1) * window_size + 1;
            end_idx = min(i * window_size, Nz);
            F0(start_idx:end_idx) = prctile(trace(start_idx:end_idx), percentile_value);
        end
        F0 = movmedian(F0, window_size, 'omitnan');
        F0 = smoothdata (F0,1,"gaussian",window_size/2);
        DF(n,:)=(trace-F0')./F0';
    end
    
    % WinRest=find(speedsm<=2);
    % WinActive=find(speedsm>2);
end