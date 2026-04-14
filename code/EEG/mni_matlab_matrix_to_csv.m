for i = 1:14
    
    % ----- Construct filename
    exp_id = sprintf('EXP%03d', i);
    mat_filename = sprintf('%s_MNI_coordinates.mat', exp_id);
    
    % ----- Load .mat file
    S = load(mat_filename);   % loads into struct
    
    P = S.P_mni;
    L = S.label;
    
    % ----- Clean labels (optional but recommended)
    L = strtrim(L);
    
    % ----- Create table
    T = table(L, P(:,1), P(:,2), P(:,3), ...
        'VariableNames', {'contact', 'MNI_x', 'MNI_y', 'MNI_z'});
    
    % ----- Optional: create standardized electrode_id
    T.electrode_id = strcat(exp_id, "_", T.label);
    
    % Move electrode_id to first column
    T = movevars(T, 'electrode_id', 'Before', 'contact');
    
    % ----- Save as CSV
    csv_filename = sprintf('%s_electrodes.csv', exp_id);
    writetable(T, csv_filename);
    
end