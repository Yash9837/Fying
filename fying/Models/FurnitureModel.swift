import Foundation
import ARKit
import Combine
import SceneKit

// MARK: - Furniture Category
enum FurnitureCategory: String, CaseIterable, Codable {
    case seating = "Seating"
    case tables = "Tables"
    case storage = "Storage"
    case lighting = "Lighting"
    case decor = "Decor"
    
    var icon: String {
        switch self {
        case .seating: return "chair"
        case .tables: return "table"
        case .storage: return "cabinet"
        case .lighting: return "lightbulb"
        case .decor: return "photo"
        }
    }
}

// MARK: - Furniture Item
struct FurnitureItem: Identifiable, Codable , Equatable{
    let id = UUID()
    let name: String
    let category: FurnitureCategory
    let modelName: String
    let thumbnailName: String
    let defaultScale: Float
    let defaultRotation: Float
    let price: Double
    let description: String
    
    // USDZ model properties
    var modelURL: URL? {
        Bundle.main.url(forResource: modelName, withExtension: "usdz")
    }
    
    var thumbnailURL: URL? {
        Bundle.main.url(forResource: thumbnailName, withExtension: "jpg")
    }
    
    // Fallback geometry for missing models
    var fallbackGeometry: SCNGeometry {
        switch category {
        case .seating:
            return SCNBox(width: 0.6, height: 0.8, length: 0.6, chamferRadius: 0.05)
        case .tables:
            return SCNBox(width: 1.2, height: 0.45, length: 0.8, chamferRadius: 0.05)
        case .storage:
            return SCNBox(width: 0.8, height: 1.8, length: 0.4, chamferRadius: 0.05)
        case .lighting:
            return SCNCylinder(radius: 0.1, height: 0.6)
        case .decor:
            return SCNBox(width: 0.5, height: 0.5, length: 0.1, chamferRadius: 0.02)
        }
    }
    
    var fallbackMaterial: SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = categoryColor
        material.metalness.contents = 0.1
        material.roughness.contents = 0.8
        return material
    }
    
    private var categoryColor: UIColor {
        switch category {
        case .seating: return UIColor.systemBlue
        case .tables: return UIColor.systemBrown
        case .storage: return UIColor.systemGray
        case .lighting: return UIColor.systemYellow
        case .decor: return UIColor.systemGreen
        }
    }
}

// MARK: - Placed Furniture
class PlacedFurniture: ObservableObject, Identifiable {
    let id = UUID()
    let furnitureItem: FurnitureItem
    let anchor: ARAnchor
    
    @Published var position: SCNVector3
    @Published var rotation: SCNVector4
    @Published var scale: SCNVector3
    @Published var isSelected: Bool = false
    
    init(furnitureItem: FurnitureItem, anchor: ARAnchor, position: SCNVector3) {
        self.furnitureItem = furnitureItem
        self.anchor = anchor
        self.position = position
        self.rotation = SCNVector4(0, 1, 0, 0) // Default rotation
        self.scale = SCNVector3(furnitureItem.defaultScale, furnitureItem.defaultScale, furnitureItem.defaultScale)
    }
    
    func updatePosition(_ newPosition: SCNVector3) {
        position = newPosition
    }
    
    func updateRotation(_ newRotation: SCNVector4) {
        rotation = newRotation
    }
    
    func updateScale(_ newScale: SCNVector3) {
        scale = newScale
    }
    
    func toggleSelection() {
        isSelected.toggle()
    }
}

// MARK: - Furniture Catalog
class FurnitureCatalog: ObservableObject {
    @Published var furnitureItems: [FurnitureItem] = []
    @Published var selectedCategory: FurnitureCategory = .seating
    
    init() {
        loadFurnitureCatalog()
    }
    
    private func loadFurnitureCatalog() {
        // Sample furniture items - in a real app, this would come from a database or API
        furnitureItems = [
            // Seating
            FurnitureItem(name: "Modern Chair", category: .seating, modelName: "modern_chair", thumbnailName: "chair_thumb", defaultScale: 1.0, defaultRotation: 0, price: 299.99, description: "Contemporary design chair with ergonomic features"),
            FurnitureItem(name: "Comfortable Sofa", category: .seating, modelName: "sofa", thumbnailName: "sofa_thumb", defaultScale: 1.2, defaultRotation: 0, price: 899.99, description: "Comfortable 3-seater sofa with premium fabric"),
            FurnitureItem(name: "Office Chair", category: .seating, modelName: "office_chair", thumbnailName: "office_chair_thumb", defaultScale: 1.0, defaultRotation: 0, price: 199.99, description: "Ergonomic office chair with adjustable features"),
            
            // Tables
            FurnitureItem(name: "Coffee Table", category: .tables, modelName: "coffee_table", thumbnailName: "table_thumb", defaultScale: 1.0, defaultRotation: 0, price: 199.99, description: "Elegant coffee table with glass top"),
            FurnitureItem(name: "Dining Table", category: .tables, modelName: "dining_table", thumbnailName: "dining_thumb", defaultScale: 1.5, defaultRotation: 0, price: 599.99, description: "6-seater dining table with wooden finish"),
            FurnitureItem(name: "Side Table", category: .tables, modelName: "side_table", thumbnailName: "side_table_thumb", defaultScale: 0.8, defaultRotation: 0, price: 89.99, description: "Compact side table for small spaces"),
            
            // Storage
            FurnitureItem(name: "Bookshelf", category: .storage, modelName: "bookshelf", thumbnailName: "shelf_thumb", defaultScale: 1.0, defaultRotation: 0, price: 399.99, description: "Modern bookshelf with adjustable shelves"),
            FurnitureItem(name: "Wardrobe", category: .storage, modelName: "wardrobe", thumbnailName: "wardrobe_thumb", defaultScale: 1.3, defaultRotation: 0, price: 799.99, description: "Spacious wardrobe with mirror doors"),
            FurnitureItem(name: "Chest of Drawers", category: .storage, modelName: "chest_drawers", thumbnailName: "chest_thumb", defaultScale: 1.1, defaultRotation: 0, price: 299.99, description: "Classic chest of drawers with brass handles"),
            
            // Lighting
            FurnitureItem(name: "Table Lamp", category: .lighting, modelName: "table_lamp", thumbnailName: "lamp_thumb", defaultScale: 0.8, defaultRotation: 0, price: 89.99, description: "Elegant table lamp with fabric shade"),
            FurnitureItem(name: "Floor Lamp", category: .lighting, modelName: "floor_lamp", thumbnailName: "floor_lamp_thumb", defaultScale: 1.1, defaultRotation: 0, price: 149.99, description: "Modern floor lamp with adjustable arm"),
            FurnitureItem(name: "Ceiling Light", category: .lighting, modelName: "ceiling_light", thumbnailName: "ceiling_light_thumb", defaultScale: 0.9, defaultRotation: 0, price: 129.99, description: "Contemporary ceiling light fixture"),
            
            // Decor
            FurnitureItem(name: "Plant Pot", category: .decor, modelName: "plant_pot", thumbnailName: "plant_thumb", defaultScale: 0.7, defaultRotation: 0, price: 49.99, description: "Decorative plant pot with drainage holes"),
            FurnitureItem(name: "Wall Art", category: .decor, modelName: "wall_art", thumbnailName: "art_thumb", defaultScale: 1.0, defaultRotation: 0, price: 199.99, description: "Abstract wall art with vibrant colors"),
            FurnitureItem(name: "Vase", category: .decor, modelName: "vase", thumbnailName: "vase_thumb", defaultScale: 0.6, defaultRotation: 0, price: 79.99, description: "Elegant ceramic vase for flowers")
        ]
    }
    
    func getFurnitureByCategory(_ category: FurnitureCategory) -> [FurnitureItem] {
        return furnitureItems.filter { $0.category == category }
    }
}
