classdef WaveVortexModelNetCDFTools < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        netcdfFile
        ncid
        wm
        
        ncPrecision
        bytePerFloat
        
        Nx, Ny, Nz
        xDimID, yDimID, zDimID
        xVarID, yVarID, zVarID
        
        Nk, Nl, Nj, Nt
        kDimID, lDimID, jDimID, tDimID
        kVarID, lVarID, jVarID, tVarID
        
        A0RealVarID
        A0ImagVarID
        ApRealVarID
        ApImagVarID
        AmRealVarID
        AmImagVarID
        
        EnergyIGWPlusVarID
        EnergyIGWMinusVarID
        EnergyIOBaroclinicVarID
        EnergyIOBarotropicVarID
        EnergyGeostrophicBaroclinicVarID
        EnergyGeostrophicBarotropicVarID
        EnergyResidualVarID
        EnergyDepthIntegratedVarID
        
        Nkh
        khDimID
        khVarID
        
        EnergyIGWPlusKJVarID
        EnergyIGWMinusKJVarID
        EnergyIOBaroclinicJVarID
        EnergyGeostrophicBaroclinicKJVarID
        EnergyGeostrophicBarotropicKVarID
        
        floatDimID, nFloats
        xFloatID, yFloatID, zFloatID, densityFloatID
        drifterDimID, nDrifters
        xDrifterID, yDrifterID, zDrifterID, densityDrifterID
        
        NK2unique
        K2uniqueDimID
        K2uniqueVarID
        
        iK2uniqueVarID
        SVarID
        SprimeVarID
        hVarID
        F2VarID
        G2VarID
        N2G2VarID
        nWellConditionedVarID
        didPrecomputeVarID
    end
    
    methods
        function self = WaveVortexModelNetCDFTools(netcdfFile)
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
            self.netcdfFile = netcdfFile;
        end
        
        function self = CreateNetCDFFileFromModel(self,internalWaveModel,Nt,precision)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            self.wm = internalWaveModel;
            
            self.Nk = length(self.wm.k);
            self.Nl = length(self.wm.l);
            self.Nj = length(self.wm.j);
            self.Nt = Nt;
            
            if strcmp(precision,'single')
                self.ncPrecision = 'NC_FLOAT';
                self.bytePerFloat = 4;
            else
                self.ncPrecision = 'NC_DOUBLE';
                self.bytePerFloat = 8;
            end
            
            % Chunking: https://www.unidata.ucar.edu/blogs/developer/en/entry/chunking_data_choosing_shapes
%             shouldChunk = 0;
%             [csize, nelems, premp] = netcdf.getChunkCache();
%             D = csize/self.bytePerFloat;
%             c = (D/(self.Nk*self.Nl*self.Nj*self.Nt))^(1/4);
%             chunkSize = floor(c*[self.Nk self.Nl self.Nj self.Nt]);
            
            cmode = netcdf.getConstant('CLOBBER');
            cmode = bitor(cmode,netcdf.getConstant('SHARE'));
            cmode = bitor(cmode,netcdf.getConstant('NETCDF4'));
            self.ncid = netcdf.create(self.netcdfFile, cmode);
            
            
            % Define the dimensions
            self.xDimID = netcdf.defDim(self.ncid, 'x', self.wm.Nx);
            self.yDimID = netcdf.defDim(self.ncid, 'y', self.wm.Ny);
            self.zDimID = netcdf.defDim(self.ncid, 'z', self.wm.Nz);
            % Define the coordinate variables
            self.xVarID = netcdf.defVar(self.ncid, 'x', self.ncPrecision, self.xDimID);
            self.yVarID = netcdf.defVar(self.ncid, 'y', self.ncPrecision, self.yDimID);
            self.zVarID = netcdf.defVar(self.ncid, 'z', self.ncPrecision, self.zDimID);
            netcdf.putAtt(self.ncid,self.xVarID, 'units', 'm');
            netcdf.putAtt(self.ncid,self.yVarID, 'units', 'm');
            netcdf.putAtt(self.ncid,self.zVarID, 'units', 'm');
            
            
            % Define the dimensions
            self.kDimID = netcdf.defDim(self.ncid, 'k', self.Nk);
            self.lDimID = netcdf.defDim(self.ncid, 'l', self.Nl);
            self.jDimID = netcdf.defDim(self.ncid, 'j', self.Nj);
            self.tDimID = netcdf.defDim(self.ncid, 't', self.Nt);
            
            % Define the coordinate variables
            self.kVarID = netcdf.defVar(self.ncid, 'k', self.ncPrecision, self.kDimID);
            self.lVarID = netcdf.defVar(self.ncid, 'l', self.ncPrecision, self.lDimID);
            self.jVarID = netcdf.defVar(self.ncid, 'j', self.ncPrecision, self.jDimID);
            self.tVarID = netcdf.defVar(self.ncid, 't', self.ncPrecision, self.tDimID);
            netcdf.putAtt(self.ncid,self.kVarID, 'units', 'radians/m');
            netcdf.putAtt(self.ncid,self.lVarID, 'units', 'radians/m');
            netcdf.putAtt(self.ncid,self.jVarID, 'units', 'mode number');
            netcdf.putAtt(self.ncid,self.tVarID, 'units', 's');
            
            if isa(self.wm,'WaveVortexModelConstantStratification')
                netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'stratification','constant');
                netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'N0', self.wm.N0);
            elseif isa(self.wm,'InternalWaveModelExponentialStratification')
                error('Not implemented');
%                 netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'stratification','exponential');
%                 netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'N0', self.wm.N0);
%                 netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'b', self.wm.b);
            elseif isa(self.wm,'InternalWaveModelArbitraryStratification')
                error('Not implemented');
%                 netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'stratification','custom');
%                 N2VarID = netcdf.defVar(self.ncid, 'N2', self.ncPrecision, self.zDimID);
%                 RhobarVarID = netcdf.defVar(self.ncid, 'rhobar', self.ncPrecision, self.zDimID);
            else
                error('Not implemented');
            end
            
            % Write some metadata
            netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'latitude', self.wm.latitude);
            % 
            netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'rho0', self.wm.rho0);
            netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'Model', 'Created from WaveVortexModel.m written by Jeffrey J. Early.');
            netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'ModelVersion', self.wm.version);
            netcdf.putAtt(self.ncid,netcdf.getConstant('NC_GLOBAL'), 'CreationDate', datestr(datetime('now')));
            
            % End definition mode
            netcdf.endDef(self.ncid);
            
            % Add the data for the coordinate variables
            netcdf.putVar(self.ncid, self.kVarID, self.wm.k);
            netcdf.putVar(self.ncid, self.lVarID, self.wm.l);
            netcdf.putVar(self.ncid, self.jVarID, self.wm.j);
            
            netcdf.putVar(self.ncid, self.xVarID, self.wm.x);
            netcdf.putVar(self.ncid, self.yVarID, self.wm.y);
            netcdf.putVar(self.ncid, self.zVarID, self.wm.z);
            
            if isa(self.wm,'InternalWaveModelArbitraryStratification')
                netcdf.putVar(self.ncid, N2VarID, self.wm.N2);
                netcdf.putVar(self.ncid, RhobarVarID, self.wm.RhoBarAtDepth(self.wm.z));
                self.CreateTransformationVariables();
            end
            
            % Apple uses 1e9 bytes as 1 GB (not the usual multiples of 2 definition)
            totalFields = 6;
            totalSize = totalFields*self.bytePerFloat*self.Nt*self.Nk*self.Nl*self.Nj/1e9;
            fprintf('Writing output file to %s\nExpected file size is %.2f GB.\n',self.netcdfFile,totalSize);
        end
        
        function wavemodel = InitializeWaveModelFromNetCDFFile(self)
            x = ncread(self.netcdfFile,'x');
            y = ncread(self.netcdfFile,'y');
            z = ncread(self.netcdfFile,'z');
            j = ncread(self.netcdfFile,'j');
            latitude = ncreadatt(self.netcdfFile,'/','latitude');
            stratification = ncreadatt(self.netcdfFile,'/','stratification');
            
            self.Nx = length(x);
            self.Ny = length(y);
            self.Nz = length(z);
            
            Lx = (x(2)-x(1))*self.Nx; 
            Ly = (y(2)-y(1))*self.Ny; 
            Lz = max(z)-min(z); 
            
            if strcmp(stratification,'custom')
                nModes = length(j);
                rhobar = ncread(self.netcdfFile,'rhobar');
                N2 = ncread(self.netcdfFile,'N2');
                self.wm = InternalWaveModelArbitraryStratification([Lx Ly Lz],[self.Nx self.Ny self.Nz], rhobar, z, latitude,'nModes',nModes);
                self.wm.N2 = N2;
                self.wm.ReadEigenmodesFromNetCDFCache(self.netcdfFile);
            else
                N0 = ncreadatt(self.netcdfFile,'/','N0');
                rho0 = ncreadatt(self.netcdfFile,'/','rho0');
                self.wm = WaveVortexModelConstantStratification([Lx Ly Lz],[self.Nx self.Ny self.Nz],latitude,N0,rho0);
            end
            
            self.SetWaveModelToIndex(1);
            
            wavemodel = self.wm;
        end
        
        function t = SetWaveModelToIndex(self,iTime)
            Ap_realp = ncread(self.netcdfFile,'Ap_realp',[1 1 1 iTime], [Inf Inf Inf 1]);
            Ap_imagp = ncread(self.netcdfFile,'Ap_imagp',[1 1 1 iTime], [Inf Inf Inf 1]);
            Am_realp = ncread(self.netcdfFile,'Am_realp',[1 1 1 iTime], [Inf Inf Inf 1]);
            Am_imagp = ncread(self.netcdfFile,'Am_imagp',[1 1 1 iTime], [Inf Inf Inf 1]);
            A0_realp = ncread(self.netcdfFile,'A0_realp',[1 1 1 iTime], [Inf Inf Inf 1]);
            A0_imagp = ncread(self.netcdfFile,'A0_imagp',[1 1 1 iTime], [Inf Inf Inf 1]);
                        
            % Stuff these values back into the wavemodel (which is where they
            % came from in the first place)
            self.wm.A0 = A0_realp + sqrt(-1)*A0_imagp;
            self.wm.Ap = Ap_realp + sqrt(-1)*Ap_imagp;
            self.wm.Am = Am_realp + sqrt(-1)*Am_imagp;
            
            t = ncread(self.netcdfFile,'t',iTime,1);
        end
        
        function self = CreateAmplitudeCoefficientVariables(self)
            netcdf.reDef(self.ncid);
            
            % Define the wave-vortex variables
            self.A0RealVarID = netcdf.defVar(self.ncid, 'A0_realp', self.ncPrecision, [self.kDimID,self.lDimID,self.jDimID,self.tDimID]);
            self.A0ImagVarID = netcdf.defVar(self.ncid, 'A0_imagp', self.ncPrecision, [self.kDimID,self.lDimID,self.jDimID,self.tDimID]);
            self.ApRealVarID = netcdf.defVar(self.ncid, 'Ap_realp', self.ncPrecision, [self.kDimID,self.lDimID,self.jDimID,self.tDimID]);
            self.ApImagVarID = netcdf.defVar(self.ncid, 'Ap_imagp', self.ncPrecision, [self.kDimID,self.lDimID,self.jDimID,self.tDimID]);
            self.AmRealVarID = netcdf.defVar(self.ncid, 'Am_realp', self.ncPrecision, [self.kDimID,self.lDimID,self.jDimID,self.tDimID]);
            self.AmImagVarID = netcdf.defVar(self.ncid, 'Am_imagp', self.ncPrecision, [self.kDimID,self.lDimID,self.jDimID,self.tDimID]);

            % netcdf.putAtt(self.ncid,ApRealVarID, 'units', 'm^{3/2}/s');
            % netcdf.putAtt(self.ncid,ApImagVarID, 'units', 'm^{3/2}/s');
            % netcdf.putAtt(self.ncid,AmRealVarID, 'units', 'm^{3/2}/s');
            % netcdf.putAtt(self.ncid,AmImagVarID, 'units', 'm^{3/2}/s');
            % netcdf.putAtt(self.ncid,BRealVarID, 'units', 'm');
            % netcdf.putAtt(self.ncid,BImagVarID, 'units', 'm');
            % netcdf.putAtt(self.ncid,B0RealVarID, 'units', 'm');
            % netcdf.putAtt(self.ncid,B0ImagVarID, 'units', 'm');
            
            netcdf.endDef(self.ncid);
        end
        
        function self = CreateEnergeticsVariables(self)
            netcdf.reDef(self.ncid);
            
            self.EnergyIGWPlusVarID = netcdf.defVar(self.ncid, 'EnergyIGWPlus', self.ncPrecision, self.tDimID);
            self.EnergyIGWMinusVarID = netcdf.defVar(self.ncid, 'EnergyIGWMinus', self.ncPrecision, self.tDimID);
            self.EnergyIOBaroclinicVarID = netcdf.defVar(self.ncid, 'EnergyIOBaroclinic', self.ncPrecision, self.tDimID);
            self.EnergyIOBarotropicVarID = netcdf.defVar(self.ncid, 'EnergyIOBarotropic', self.ncPrecision, self.tDimID);
            self.EnergyGeostrophicBaroclinicVarID = netcdf.defVar(self.ncid, 'EnergyGeostrophicBaroclinic', self.ncPrecision, self.tDimID);
            self.EnergyGeostrophicBarotropicVarID = netcdf.defVar(self.ncid, 'EnergyGeostrophicBarotropic', self.ncPrecision, self.tDimID);
            
%             self.EnergyResidualVarID = netcdf.defVar(self.ncid, 'EnergyResidual', self.ncPrecision, self.tDimID);
%             self.EnergyDepthIntegratedVarID = netcdf.defVar(self.ncid, 'EnergyDepthIntegrated', self.ncPrecision, self.tDimID);
            
            netcdf.endDef(self.ncid);
        end
        
        function self = CreateEnergeticsKJVariables(self)
            netcdf.reDef(self.ncid);
            
            k = self.wm.IsotropicKAxis();
            self.Nkh = length(k);
            self.khDimID = netcdf.defDim(self.ncid, 'kh', self.Nkh);
            self.khVarID = netcdf.defVar(self.ncid, 'kh', self.ncPrecision, self.khDimID);
            netcdf.putAtt(self.ncid,self.khVarID, 'units', 'radians/m');
            
            self.EnergyIGWPlusKJVarID = netcdf.defVar(self.ncid, 'EnergyIGWPlusKJ', self.ncPrecision, [self.khDimID,self.jDimID,self.tDimID]);
            self.EnergyIGWMinusKJVarID = netcdf.defVar(self.ncid, 'EnergyIGWMinusKJ', self.ncPrecision, [self.khDimID,self.jDimID,self.tDimID]);
            self.EnergyIOBaroclinicJVarID = netcdf.defVar(self.ncid, 'EnergyIOBaroclinicJ', self.ncPrecision, [self.jDimID,self.tDimID]);
            self.EnergyGeostrophicBaroclinicKJVarID = netcdf.defVar(self.ncid, 'EnergyGeostrophicBaroclinicKJ', self.ncPrecision, [self.khDimID,self.jDimID,self.tDimID]);
            self.EnergyGeostrophicBarotropicKVarID = netcdf.defVar(self.ncid, 'EnergyGeostrophicBarotropicK', self.ncPrecision, [self.khDimID,self.tDimID]);
            
            [~,~,omegaN,n] = self.wm.ConvertToWavenumberAndMode(abs(self.wm.Omega),ones(size(self.wm.Omega)));
            omegaKJ = omegaN./n;
            omegaKJVarID = netcdf.defVar(self.ncid, 'omegaKJ', self.ncPrecision, [self.khDimID,self.jDimID]);
            
            netcdf.endDef(self.ncid);
            
            netcdf.putVar(self.ncid, self.khVarID, k);
            netcdf.putVar(self.ncid, omegaKJVarID, omegaKJ);
        end
        
        function self = CreateFloatVariables(self,nFloats)
            netcdf.reDef(self.ncid);
            
            self.nFloats = nFloats;
            self.floatDimID = netcdf.defDim(self.ncid, 'float_id', nFloats);
            self.xFloatID = netcdf.defVar(self.ncid, 'x-position', self.ncPrecision, [self.floatDimID,self.tDimID]);
            self.yFloatID = netcdf.defVar(self.ncid, 'y-position', self.ncPrecision, [self.floatDimID,self.tDimID]);
            self.zFloatID = netcdf.defVar(self.ncid, 'z-position', self.ncPrecision, [self.floatDimID,self.tDimID]);
            self.densityFloatID = netcdf.defVar(self.ncid, 'density-float', self.ncPrecision, [self.floatDimID,self.tDimID]);
            netcdf.putAtt(self.ncid,self.xFloatID, 'units', 'm');
            netcdf.putAtt(self.ncid,self.yFloatID, 'units', 'm');
            netcdf.putAtt(self.ncid,self.zFloatID, 'units', 'm');
            
            netcdf.endDef(self.ncid);
        end
        
        function self = CreateDrifterVariables(self,nDrifters)
            netcdf.reDef(self.ncid);
            
            self.nDrifters = nDrifters;
            self.drifterDimID = netcdf.defDim(self.ncid, 'drifter_id', nDrifters);
            self.xDrifterID = netcdf.defVar(self.ncid, 'x-drifter-position', self.ncPrecision, [self.drifterDimID,self.tDimID]);
            self.yDrifterID = netcdf.defVar(self.ncid, 'y-drifter-position', self.ncPrecision, [self.drifterDimID,self.tDimID]);
            self.zDrifterID = netcdf.defVar(self.ncid, 'z-drifter-position', self.ncPrecision, [self.drifterDimID,self.tDimID]);
            self.densityDrifterID = netcdf.defVar(self.ncid, 'density-drifter', self.ncPrecision, [self.drifterDimID,self.tDimID]);
            netcdf.putAtt(self.ncid,self.xDrifterID, 'units', 'm');
            netcdf.putAtt(self.ncid,self.yDrifterID, 'units', 'm');
            netcdf.putAtt(self.ncid,self.zDrifterID, 'units', 'm');
            
            netcdf.endDef(self.ncid);
        end
        
        function self = CreateTransformationVariables(self)
            netcdf.reDef(self.ncid);
            
            self.NK2unique = length(self.wm.K2unique);
            self.K2uniqueDimID = netcdf.defDim(self.ncid, 'K2unique', self.NK2unique);
            self.K2uniqueVarID = netcdf.defVar(self.ncid, 'K2unique', self.ncPrecision, self.K2uniqueDimID);
            netcdf.putAtt(self.ncid,self.K2uniqueVarID, 'units', 'radians/m');
            
            self.iK2uniqueVarID = netcdf.defVar(self.ncid, 'iK2unique', self.ncPrecision, [self.kDimID,self.lDimID]);
            self.SVarID = netcdf.defVar(self.ncid, 'S', self.ncPrecision, [self.zDimID, self.jDimID, self.K2uniqueDimID]);
            self.SprimeVarID = netcdf.defVar(self.ncid, 'Sprime', self.ncPrecision, [self.zDimID, self.jDimID, self.K2uniqueDimID]);
            self.hVarID = netcdf.defVar(self.ncid, 'h_unique', self.ncPrecision, [self.K2uniqueDimID,self.jDimID]);
            self.F2VarID = netcdf.defVar(self.ncid, 'F2_unique', self.ncPrecision,  [self.K2uniqueDimID,self.jDimID]);
            self.G2VarID = netcdf.defVar(self.ncid, 'G2_unique', self.ncPrecision,  [self.K2uniqueDimID,self.jDimID]);
            self.N2G2VarID = netcdf.defVar(self.ncid, 'N2G2_unique', self.ncPrecision,  [self.K2uniqueDimID,self.jDimID]);
            self.nWellConditionedVarID = netcdf.defVar(self.ncid, 'NumberOfWellConditionedModes', self.ncPrecision, self.K2uniqueDimID);
            self.didPrecomputeVarID = netcdf.defVar(self.ncid, 'didPrecomputedModesForK2unique', self.ncPrecision, self.K2uniqueDimID);
            
            netcdf.endDef(self.ncid);
            
            netcdf.putVar(self.ncid, self.K2uniqueVarID, self.wm.K2unique);
            netcdf.putVar(self.ncid, self.iK2uniqueVarID, self.wm.iK2unique);
            netcdf.putVar(self.ncid, self.SVarID, self.wm.S);
            netcdf.putVar(self.ncid, self.SprimeVarID, self.wm.Sprime);
            netcdf.putVar(self.ncid, self.hVarID, self.wm.h_unique);
            netcdf.putVar(self.ncid, self.F2VarID, self.wm.F2_unique);
            netcdf.putVar(self.ncid, self.G2VarID, self.wm.G2_unique);
            netcdf.putVar(self.ncid, self.N2G2VarID, self.wm.N2G2_unique);
            netcdf.putVar(self.ncid, self.nWellConditionedVarID, self.wm.NumberOfWellConditionedModes);
            netcdf.putVar(self.ncid, self.didPrecomputeVarID, self.wm.didPrecomputedModesForK2unique);
        end
        
        function self = WriteTimeAtIndex(self,iTime,t)
            netcdf.putVar(self.ncid, self.tVarID, iTime-1, 1, t);
        end
        
        function self = WriteAmplitudeCoefficientsAtIndex(self,iTime)
            netcdf.putVar(self.ncid, self.A0RealVarID, [0 0 0 iTime-1], [self.Nk self.Nl self.Nj 1], real(self.wm.A0));
            netcdf.putVar(self.ncid, self.A0ImagVarID, [0 0 0 iTime-1], [self.Nk self.Nl self.Nj 1], imag(self.wm.A0));
            netcdf.putVar(self.ncid, self.ApRealVarID, [0 0 0 iTime-1], [self.Nk self.Nl self.Nj 1], real(self.wm.Ap));
            netcdf.putVar(self.ncid, self.ApImagVarID, [0 0 0 iTime-1], [self.Nk self.Nl self.Nj 1], imag(self.wm.Ap));
            netcdf.putVar(self.ncid, self.AmRealVarID, [0 0 0 iTime-1], [self.Nk self.Nl self.Nj 1], real(self.wm.Am));
            netcdf.putVar(self.ncid, self.AmImagVarID, [0 0 0 iTime-1], [self.Nk self.Nl self.Nj 1], imag(self.wm.Am));
        end
        
%         function self = WriteEnergeticsAtIndex(self,iTime,residualEnergy,depthIntegrated)
        function self = WriteEnergeticsAtIndex(self,iTime)
            netcdf.putVar(self.ncid, self.EnergyIGWPlusVarID, iTime-1, 1, self.wm.internalWaveEnergyPlus);
            netcdf.putVar(self.ncid, self.EnergyIGWMinusVarID, iTime-1, 1, self.wm.internalWaveEnergyMinus);
            netcdf.putVar(self.ncid, self.EnergyIOBaroclinicVarID, iTime-1, 1, self.wm.baroclinicInertialEnergy);
            netcdf.putVar(self.ncid, self.EnergyIOBarotropicVarID, iTime-1, 1, self.wm.barotropicInertialEnergy);
            netcdf.putVar(self.ncid, self.EnergyGeostrophicBaroclinicVarID, iTime-1, 1, self.wm.baroclinicGeostrophicEnergy);
            netcdf.putVar(self.ncid, self.EnergyGeostrophicBarotropicVarID, iTime-1, 1, self.wm.barotropicGeostrophicEnergy);
            
%             netcdf.putVar(self.ncid, self.EnergyResidualVarID, iTime-1, 1, residualEnergy);
%             netcdf.putVar(self.ncid, self.EnergyDepthIntegratedVarID, iTime-1, 1, depthIntegrated);
        end
        
        function self = WriteFloatPositionsAtIndex(self,iTime,x,y,z,density)
            netcdf.putVar(self.ncid, self.xFloatID, [0 iTime-1], [self.nFloats 1], x);
            netcdf.putVar(self.ncid, self.yFloatID, [0 iTime-1], [self.nFloats 1], y);
            netcdf.putVar(self.ncid, self.zFloatID, [0 iTime-1], [self.nFloats 1], z);
            netcdf.putVar(self.ncid, self.densityFloatID, [0 iTime-1], [self.nFloats 1], density);
        end
        
        function self = WriteDrifterPositionsAtIndex(self,iTime,x,y,z,density)
            netcdf.putVar(self.ncid, self.xDrifterID, [0 iTime-1], [self.nDrifters 1], x);
            netcdf.putVar(self.ncid, self.yDrifterID, [0 iTime-1], [self.nDrifters 1], y);
            netcdf.putVar(self.ncid, self.zDrifterID, [0 iTime-1], [self.nDrifters 1], z);
            netcdf.putVar(self.ncid, self.densityDrifterID, [0 iTime-1], [self.nDrifters 1], density);
        end
        
        function self = WriteEnergeticsKJAtIndex(self,iTime)
            [~,~,IGWPlusEnergyKJ,IGWMinusEnergyKJ,GeostrophicEnergyKJ,GeostrophicBarotropicEnergyK,IOEnergyJ] = self.wm.energeticsByWavenumberAndMode();
            netcdf.putVar(self.ncid, self.EnergyIGWPlusKJVarID, [0 0 iTime-1], [self.Nkh self.Nj 1], IGWPlusEnergyKJ);
            netcdf.putVar(self.ncid, self.EnergyIGWMinusKJVarID, [0 0 iTime-1], [self.Nkh self.Nj 1], IGWMinusEnergyKJ);
            netcdf.putVar(self.ncid, self.EnergyIOBaroclinicJVarID, [0 iTime-1], [self.Nj 1], IOEnergyJ);
            netcdf.putVar(self.ncid, self.EnergyGeostrophicBaroclinicKJVarID, [0 0 iTime-1], [self.Nkh self.Nj 1], GeostrophicEnergyKJ);
            netcdf.putVar(self.ncid, self.EnergyGeostrophicBarotropicKVarID, [0 iTime-1], [self.Nkh 1], GeostrophicBarotropicEnergyK);
        end
        
        function self = close(self)
           netcdf.close(self.ncid); 
        end
    end
end

