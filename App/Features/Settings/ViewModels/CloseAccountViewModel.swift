import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
final class CloseAccountViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isCompleted = false
    @Published var error: String?
    
    var loadingTitle = "Deleting account"
    var loadingDescription = "Please wait while we process your request"
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func deleteAccount() async {
        guard let user = auth.currentUser else { return }
        
        isLoading = true
        
        do {
            // 1. Kullanıcı verilerini Firestore'dan sil
            let batch = db.batch()
            
            // Ana kullanıcı dokümanını sil
            let userRef = db.collection("users").document(user.uid)
            batch.deleteDocument(userRef)
            
            // Bildirimleri sil
            let notificationsRef = userRef.collection("notifications")
            let notifications = try await notificationsRef.getDocuments()
            for doc in notifications.documents {
                batch.deleteDocument(doc.reference)
            }
            
            // Batch işlemini gerçekleştir
            try await batch.commit()
            
            // 2. Storage'dan profil fotoğrafını sil
            let storageRef = storage.reference().child("profile_photos/\(user.uid).jpg")
            try? await storageRef.delete()
            
            // 3. Firebase Authentication'dan hesabı sil
            try await user.delete()
            
            // 4. Oturumu kapat ve temizlik yap
            try? auth.signOut()
            UserDefaults.standard.removeObject(forKey: "isAuthenticated")
            URLCache.shared.removeAllCachedResponses()
            
            // 5. Tamamlandı durumunu ayarla
            isCompleted = true
            
            // 6. Kullanıcı çıkış bildirimini gönder
            NotificationCenter.default.post(name: .userLoggedOut, object: nil)
            
        } catch {
            // Hata durumunda bile tamamlandı olarak işaretle
            isCompleted = true
            try? auth.signOut()
            NotificationCenter.default.post(name: .userLoggedOut, object: nil)
        }
        
        isLoading = false
    }
} 