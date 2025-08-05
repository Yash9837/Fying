import SwiftUI

// MARK: - Furniture Catalog View
struct FurnitureCatalogView: View {
    @ObservedObject var viewModel: ARViewModel
    @State private var selectedCategory: FurnitureCategory = .seating
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 15) {
                Text("Furniture Catalog")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Category selector
                CategorySelectorView(selectedCategory: $selectedCategory)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            
            // Furniture grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                    ForEach(viewModel.furnitureCatalog.getFurnitureByCategory(selectedCategory)) { item in
                        FurnitureItemView(item: item) {
                            viewModel.selectFurniture(item)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.6))
    }
}

// MARK: - Category Selector View
struct CategorySelectorView: View {
    @Binding var selectedCategory: FurnitureCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FurnitureCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let category: FurnitureCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .blue)
            }
            .frame(width: 80, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.2))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Furniture Item View
struct FurnitureItemView: View {
    let item: FurnitureItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                    
                    if let thumbnailURL = item.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                        } placeholder: {
                            Image(systemName: item.category.icon)
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                
                // Item details
                VStack(spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text("$\(String(format: "%.2f", item.price))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



// MARK: - Placed Furniture Row View
struct PlacedFurnitureRowView: View {
    let furniture: PlacedFurniture
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Furniture icon
            Image(systemName: furniture.furnitureItem.category.icon)
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .white)
                .frame(width: 30)
            
            // Furniture details
            VStack(alignment: .leading, spacing: 2) {
                Text(furniture.furnitureItem.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Position: (\(String(format: "%.1f", furniture.position.x)), \(String(format: "%.1f", furniture.position.z)))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
} 
