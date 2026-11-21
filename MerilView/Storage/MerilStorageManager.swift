import Foundation

/// Central thread-safe persistent storage manager for local DICOM studies, series, and instances.
public final class MerilStorageManager {
    
    public static let shared = MerilStorageManager()
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.merilview.storage", attributes: .concurrent)
    
    private let baseDir: URL
    private let dicomDir: URL
    private let patientsDir: URL
    private let annotationsDir: URL
    private let segmentationsDir: URL
    private let dbFile: URL
    
    // In-memory repositories indexed by UID
    private var studies: [String: DicomStudy] = [:]
    private var seriesMap: [String: DicomSeries] = [:]
    private var instancesMap: [String: [DicomInstance]] = [:] // seriesUid -> [instances]
    private var allInstances: [String: DicomInstance] = [:] // sopUid -> instance
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
                         fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("MerilView", isDirectory: true)
        dicomDir = baseDir.appendingPathComponent("DICOM", isDirectory: true)
        patientsDir = dicomDir.appendingPathComponent("Patients", isDirectory: true)
        annotationsDir = baseDir.appendingPathComponent("Annotations", isDirectory: true)
        segmentationsDir = baseDir.appendingPathComponent("Segmentations", isDirectory: true)
        dbFile = baseDir.appendingPathComponent("pacs_database.json")
        
        try? fileManager.createDirectory(at: patientsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: annotationsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: segmentationsDir, withIntermediateDirectories: true)
        
        loadDatabase()
    }
    
    // MARK: - Database Persistence
    
    private func loadDatabase() {
        guard fileManager.fileExists(atPath: dbFile.path) else { return }
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: self.dbFile)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Studies
                if let studiesArray = json?["studies"] as? [[String: Any]] {
                    for dict in studiesArray {
                        if let uid = dict["studyInstanceUid"] as? String {
                            let study = DicomStudy(
                                studyInstanceUid: uid,
                                patientName: dict["patientName"] as? String ?? "Anonymous",
                                patientId: dict["patientId"] as? String ?? "UNKNOWN",
                                patientBirthDate: dict["patientBirthDate"] as? String,
                                patientSex: dict["patientSex"] as? String,
                                studyDate: dict["studyDate"] as? String ?? "",
                                studyTime: dict["studyTime"] as? String,
                                studyDescription: dict["studyDescription"] as? String ?? "",
                                modalities: dict["modalities"] as? String ?? "CT",
                                numberOfSeries: dict["numberOfSeries"] as? Int ?? 1,
                                numberOfInstances: dict["numberOfInstances"] as? Int ?? 0,
                                institution: dict["institution"] as? String,
                                isLocal: true
                            )
                            self.studies[uid] = study
                        }
                    }
                }
                
                // Series
                if let seriesArray = json?["series"] as? [[String: Any]] {
                    for dict in seriesArray {
                        if let uid = dict["seriesInstanceUid"] as? String,
                           let studyUid = dict["studyInstanceUid"] as? String {
                            let series = DicomSeries(
                                seriesInstanceUid: uid,
                                studyInstanceUid: studyUid,
                                seriesNumber: dict["seriesNumber"] as? Int ?? 1,
                                modality: dict["modality"] as? String ?? "CT",
                                seriesDescription: dict["seriesDescription"] as? String ?? "",
                                numberOfInstances: dict["numberOfInstances"] as? Int ?? 0,
                                sliceThickness: dict["sliceThickness"] as? Double ?? 2.0
                            )
                            self.seriesMap[uid] = series
                        }
                    }
                }
                
                // Instances
                if let instancesArray = json?["instances"] as? [[String: Any]] {
                    for dict in instancesArray {
                        if let sopUid = dict["sopInstanceUid"] as? String,
                           let seriesUid = dict["seriesInstanceUid"] as? String,
                           let studyUid = dict["studyInstanceUid"] as? String,
                           let filePath = dict["filePath"] as? String {
                            
                            let inst = DicomInstance(
                                sopInstanceUid: sopUid,
                                seriesInstanceUid: seriesUid,
                                studyInstanceUid: studyUid,
                                instanceNumber: dict["instanceNumber"] as? Int ?? 1,
                                rows: dict["rows"] as? Int ?? 512,
                                columns: dict["columns"] as? Int ?? 512,
                                bitsAllocated: dict["bitsAllocated"] as? Int ?? 16,
                                bitsStored: dict["bitsStored"] as? Int ?? 12,
                                pixelRepresentation: dict["pixelRepresentation"] as? Int ?? 0,
                                pixelSpacing: dict["pixelSpacing"] as? [Double] ?? [1.0, 1.0],
                                sliceThickness: dict["sliceThickness"] as? Double ?? 2.0,
                                sliceLocation: dict["sliceLocation"] as? Double ?? 0.0,
                                imagePositionPatient: dict["imagePositionPatient"] as? [Double] ?? [0.0, 0.0, 0.0],
                                imageOrientationPatient: dict["imageOrientationPatient"] as? [Double] ?? [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
                                windowCenter: dict["windowCenter"] as? Double ?? 40.0,
                                windowWidth: dict["windowWidth"] as? Double ?? 400.0,
                                rescaleSlope: dict["rescaleSlope"] as? Double ?? 1.0,
                                rescaleIntercept: dict["rescaleIntercept"] as? Double ?? 0.0,
                                filePath: filePath,
                                transferSyntaxUid: dict["transferSyntaxUid"] as? String ?? "1.2.840.10008.1.2.1"
                            )
                            self.allInstances[sopUid] = inst
                            if self.instancesMap[seriesUid] == nil {
                                self.instancesMap[seriesUid] = []
                            }
                            self.instancesMap[seriesUid]?.append(inst)
                        }
                    }
                }
            } catch {
                print("[MerilStorageManager] Error loading database: \(error)")
            }
        }
    }
    
    private func saveDatabase() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            do {
                var root: [String: Any] = [:]
                
                // Studies
                root["studies"] = self.studies.values.map { s in
                    [
                        "studyInstanceUid": s.studyInstanceUid,
                        "patientName": s.patientName,
                        "patientId": s.patientId,
                        "patientBirthDate": s.patientBirthDate ?? "",
                        "patientSex": s.patientSex ?? "O",
                        "studyDate": s.studyDate,
                        "studyTime": s.studyTime ?? "",
                        "studyDescription": s.studyDescription,
                        "modalities": s.modalities,
                        "numberOfSeries": s.numberOfSeries,
                        "numberOfInstances": s.numberOfInstances,
                        "institution": s.institution ?? ""
                    ]
                }
                
                // Series
                root["series"] = self.seriesMap.values.map { s in
                    [
                        "seriesInstanceUid": s.seriesInstanceUid,
                        "studyInstanceUid": s.studyInstanceUid,
                        "seriesNumber": s.seriesNumber,
                        "modality": s.modality,
                        "seriesDescription": s.seriesDescription,
                        "numberOfInstances": s.numberOfInstances,
                        "sliceThickness": s.sliceThickness ?? 2.0
                    ]
                }
                
                // Instances
                root["instances"] = self.allInstances.values.map { inst in
                    [
                        "sopInstanceUid": inst.sopInstanceUid,
                        "seriesInstanceUid": inst.seriesInstanceUid,
                        "studyInstanceUid": inst.studyInstanceUid,
                        "instanceNumber": inst.instanceNumber,
                        "rows": inst.rows,
                        "columns": inst.columns,
                        "bitsAllocated": inst.bitsAllocated,
                        "bitsStored": inst.bitsStored,
                        "pixelRepresentation": inst.pixelRepresentation,
                        "pixelSpacing": inst.pixelSpacing,
                        "sliceThickness": inst.sliceThickness,
                        "sliceLocation": inst.sliceLocation ?? 0.0,
                        "imagePositionPatient": inst.imagePositionPatient,
                        "imageOrientationPatient": inst.imageOrientationPatient,
                        "windowCenter": inst.windowCenter,
                        "windowWidth": inst.windowWidth,
                        "rescaleSlope": inst.rescaleSlope,
                        "rescaleIntercept": inst.rescaleIntercept,
                        "filePath": inst.filePath,
                        "transferSyntaxUid": inst.transferSyntaxUid
                    ]
                }
                
                let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted])
                let tempUrl = self.baseDir.appendingPathComponent("pacs_database.json.tmp")
                try data.write(to: tempUrl, options: .atomic)
                _ = try? self.fileManager.removeItem(at: self.dbFile)
                try self.fileManager.moveItem(at: tempUrl, to: self.dbFile)
            } catch {
                print("[MerilStorageManager] Error saving database: \(error)")
            }
        }
    }
    
    // MARK: - Queries
    
    public func getStudies() -> [DicomStudy] {
        queue.sync {
            Array(studies.values).sorted { $0.studyDate > $1.studyDate }
        }
    }
    
    public func getSeries(studyInstanceUid: String) -> [DicomSeries] {
        queue.sync {
            seriesMap.values
                .filter { $0.studyInstanceUid == studyInstanceUid }
                .sorted { $0.seriesNumber < $1.seriesNumber }
        }
    }
    
    public func getInstances(seriesInstanceUid: String) -> [DicomInstance] {
        queue.sync {
            let list = instancesMap[seriesInstanceUid] ?? []
            // Sort anatomically by projected position or instance number
            return list.sorted { $0.instanceNumber < $1.instanceNumber }
        }
    }
    
    public func isDuplicate(sopInstanceUid: String) -> Bool {
        queue.sync {
            if let inst = allInstances[sopInstanceUid] {
                return fileManager.fileExists(atPath: inst.filePath)
            }
            return false
        }
    }
    
    // MARK: - Ingestion
    
    public func persistDicomFile(data: Data, metadata: DicomMetadata) throws -> DicomInstance {
        let safePatientId = sanitize(metadata.patientId.isEmpty ? "UNKNOWN" : metadata.patientId)
        let safeStudyUid = sanitize(metadata.studyInstanceUid)
        let safeSeriesUid = sanitize(metadata.seriesInstanceUid)
        let safeSopUid = sanitize(metadata.sopInstanceUid)
        
        let seriesFolder = patientsDir
            .appendingPathComponent(safePatientId, isDirectory: true)
            .appendingPathComponent(safeStudyUid, isDirectory: true)
            .appendingPathComponent(safeSeriesUid, isDirectory: true)
        
        try fileManager.createDirectory(at: seriesFolder, withIntermediateDirectories: true)
        
        let targetFile = seriesFolder.appendingPathComponent("\(safeSopUid).dcm")
        try data.write(to: targetFile, options: .atomic)
        
        let instance = DicomInstance(
            sopInstanceUid: metadata.sopInstanceUid,
            seriesInstanceUid: metadata.seriesInstanceUid,
            studyInstanceUid: metadata.studyInstanceUid,
            instanceNumber: metadata.instanceNumber,
            rows: metadata.rows,
            columns: metadata.columns,
            bitsAllocated: metadata.bitsAllocated,
            bitsStored: metadata.bitsStored,
            pixelRepresentation: metadata.pixelRepresentation,
            pixelSpacing: metadata.pixelSpacing,
            sliceThickness: metadata.sliceThickness,
            sliceLocation: metadata.sliceLocation,
            imagePositionPatient: metadata.imagePositionPatient,
            imageOrientationPatient: metadata.imageOrientationPatient,
            windowCenter: metadata.windowCenter,
            windowWidth: metadata.windowWidth,
            rescaleSlope: metadata.rescaleSlope,
            rescaleIntercept: metadata.rescaleIntercept,
            filePath: targetFile.path,
            transferSyntaxUid: metadata.transferSyntaxUid
        )
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.allInstances[instance.sopInstanceUid] = instance
            if self.instancesMap[instance.seriesInstanceUid] == nil {
                self.instancesMap[instance.seriesInstanceUid] = []
            }
            self.instancesMap[instance.seriesInstanceUid]?.append(instance)
            
            // Update Series
            let existingSeries = self.seriesMap[instance.seriesInstanceUid]
            let count = self.instancesMap[instance.seriesInstanceUid]?.count ?? 1
            self.seriesMap[instance.seriesInstanceUid] = DicomSeries(
                seriesInstanceUid: instance.seriesInstanceUid,
                studyInstanceUid: instance.studyInstanceUid,
                seriesNumber: metadata.seriesNumber,
                modality: metadata.modality,
                seriesDescription: metadata.seriesDescription,
                numberOfInstances: count,
                sliceThickness: metadata.sliceThickness
            )
            
            // Update Study
            let existingStudy = self.studies[instance.studyInstanceUid]
            let seriesCount = self.seriesMap.values.filter { $0.studyInstanceUid == instance.studyInstanceUid }.count
            let totalInst = self.allInstances.values.filter { $0.studyInstanceUid == instance.studyInstanceUid }.count
            self.studies[instance.studyInstanceUid] = DicomStudy(
                studyInstanceUid: instance.studyInstanceUid,
                patientName: metadata.patientName,
                patientId: metadata.patientId,
                patientBirthDate: metadata.patientBirthDate,
                patientSex: metadata.patientSex,
                studyDate: metadata.studyDate,
                studyTime: metadata.studyTime,
                studyDescription: metadata.studyDescription,
                modalities: metadata.modality,
                numberOfSeries: max(1, seriesCount),
                numberOfInstances: totalInst,
                institution: "Meril Healthcare",
                isLocal: true
            )
            
            self.saveDatabase()
        }
        
        return instance
    }
    
    // MARK: - Annotations & Segmentation Storage
    
    public func saveAnnotations(studyUid: String, seriesUid: String, sopUid: String, annotations: [DicomAnnotation]) throws {
        let fileName = "\(sanitize(studyUid))_\(sanitize(seriesUid))_\(sanitize(sopUid)).json"
        let fileUrl = annotationsDir.appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(annotations)
        try data.write(to: fileUrl, options: .atomic)
    }
    
    public func loadAnnotations(studyUid: String, seriesUid: String, sopUid: String) -> [DicomAnnotation] {
        let fileName = "\(sanitize(studyUid))_\(sanitize(seriesUid))_\(sanitize(sopUid)).json"
        let fileUrl = annotationsDir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileUrl),
              let list = try? JSONDecoder().decode([DicomAnnotation].self, from: data) else {
            return []
        }
        return list
    }
    
    private func sanitize(_ string: String) -> String {
        return string.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
    }
}
