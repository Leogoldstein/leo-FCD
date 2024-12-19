function DF = DF_processing(F, iscell)
    % Apply preprocessing steps to the data matrix DF.
    % Input:
    % - DF: Data matrix to be preprocessed.
    % Output:
    % - DF: Preprocessed data matrix.

    DF = double(F(iscell(:,1) > 0, :));

    % Savitzky-Golay filter
    DF = sgolayfilt(DF', 3, 5)' ;

    [NCell, Nz] = size(DF);
    disp(['Ncells = ' num2str(NCell)]);

    % Bleaching correction
    ws = warning('off', 'all');
    for i = 1:NCell
        p0 = polyfit(1:Nz, DF(i,:), 3);
        DF(i,:) = DF(i,:) ./ polyval(p0, 1:Nz);
    end
    warning(ws);

    % Median normalization
    DF = DF ./ median(DF, 2);
end