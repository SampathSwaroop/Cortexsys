function [A_N_l] = feedforwardLSTM_CNN(nn, m, t, newRandGen, test)
%feedforwardLSTM: Advance network by one time step.
%   The calling function must keep track of the current and final time
%   steps. 
% Note t=2 is actually the 'beginning of time', while t=1 are the inital
% conditions for the recurrent connections (typically all zeros).
% t: current time index
% newRandGen: generate new random values for dropout, denoising, etc?
% test: are we training or testing? If testing, dropout only scales layer activations

    for k=2:nn.N_l
        switch nn.l.typ{k}
            case nn.defs.TYPES.FULLY_CONNECTED
                Akm1 = cnnFlattenLayer(nn.A{k-1}.v, m, t);
                
                nn.A{k}.v(:,:,t) = nn.l.af{k}.activ(bsxfun(@plus, nn.b{k-1}, nn.W{k-1}*Akm1));
            case nn.defs.TYPES.RECURRENT
                Akm1 = cnnFlattenLayer(nn.A{k-1}.v, m, t);
                
                nn.A{k}.v(:,:,t) = nn.l.af{k}.activ(bsxfun(@plus, nn.b{k-1},...
                               nn.W{k-1, nn.rnn.i}*Akm1 + ...
                               nn.W{k-1, nn.rnn.h}*nn.A{k}.v(:,:,t-1)));
            case nn.defs.TYPES.LSTM
                Akm1 = cnnFlattenLayer(nn.A{k-1}.v, m, t);
                
                % Compute outputs of all *gates* (does not include actual LSTM unit output)
                nn.A_lstm{k}(:,:,t) = bsxfun(@plus, nn.b{k-1}, nn.W{k-1, nn.lstm.i}*Akm1 + ...
                                                               nn.W{k-1, nn.lstm.h}*nn.A{k}.v(:,:,t-1));
                % apply activations to all other gates
                nn.A_lstm{k}([nn.lstm.idx_phi nn.lstm.idx_ohm nn.lstm.idx_l],:,t) = nn.sigmoid_af.activ(nn.A_lstm{k}([nn.lstm.idx_phi nn.lstm.idx_ohm nn.lstm.idx_l],:,t)); 
                % apply activation to input gate (c)
                nn.A_lstm{k}(nn.lstm.idx_c,:,t) = nn.l.af{k}.activ(nn.A_lstm{k}(nn.lstm.idx_c,:,t)); 
                                
                % Cell states
                nn.s_c{k}(:,:,t) = nn.A_lstm{k}(nn.lstm.idx_phi,:,t).*nn.s_c{k}(:,:,t-1) + nn.A_lstm{k}(nn.lstm.idx_l,:,t).*nn.A_lstm{k}(nn.lstm.idx_c,:,t);       
                       
                % Outputs
                nn.A{k}.v(:,:,t) = nn.A_lstm{k}(nn.lstm.idx_ohm,:,t).*nn.l.af{k}.activ(nn.s_c{k}(:,:,t));   
            case nn.defs.TYPES.CONVOLUTIONAL
                nn.A{k}.v(:,:,:,:,t) = cnnConvolve(nn.A{k-1}.v(:,:,:,:,t), nn.W{k-1}, nn.b{k-1}, nn, k, m);
            case nn.defs.TYPES.AVERAGE_POOLING
                nn.A{k}.v(:,:,:,:,t) = cnnPool(nn.A{k-1}.v(:,:,:,:,t), nn.W{k-1}, nn.l.szo{k-1}, nn.l.szo{k}, nn.l.sz{k}, nn, k, m); 
            otherwise
                error('Unknown layer type!')
        end
        
        % Only generate new dropout masks for the first time step, t=2
        switch ndims(nn.A{k}.v)
            case 3
                nn.A{k}.v(:,:,t) = dropoutLayer(nn.A{k}.v(:,:,t), nn, k, newRandGen && (t<=2), test);
            case 5
                nn.A{k}.v(:,:,:,:,t) = dropoutLayer(nn.A{k}.v(:,:,:,:,t), nn, k, newRandGen && (t<=2), test);
        end
    end
    
    A_N_l = nn.A{end}.v;
end

