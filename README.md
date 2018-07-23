# Prediksi Frekuensi Gempa dengan Menggunakan Data Gempa Tahun 2008-2018

Repositori ini berisi data sejarah gempa yang terjadi di Indonesia pada tahun 2008-2018. Data tersebut diambil dari [BMKG](http://repogempa.bmkg.go.id/query.php).

Dengan memanfaatkan data tersebut, dibuatlah aplikasi Shiny untuk menampilkan prediksi kemungkinan total gempa yang akan terjadi di tiap wilayah Indonesia dalam rentang waktu tertentu dalam bentuk visual.

## Tentang Kami

Aplikasi Shiny ini dibuat oleh:
- [Clarissa Veronica Kusuma](https://github.com/clarissaveronica) (00000013004)
- [Kevin Kurniawan](https://github.com/kevinkurniawan97) (00000014200)
- [Madeleine Jose Josodipuro](https://github.com/haysacks) (00000011802)

untuk memenuhi tugas mata kuliah _Frontier Technology_ jurusan Teknik Informatika Universitas Pelita Harapan semester Akselerasi 2017/2018.

## Instalasi
Jalankan R (disarankan menggunakan RStudio). Sebelum memulai, instal beberapa _library_ yang dibutuhkan dalam pembuatan aplikasi, seperti:
  - `rvest`: _package_ yang memudahkan pengambilan data (_scraping_) dari halaman _web_ html
  - `httr`: _tools_ yang berguna ketika bekerja dengan _HTTP_, diatur dengan _HTTP verbs_ (GET(), POST(), dan lainnya)
  - `XML`: _tools_ untuk melakukan _parsing_ dan _generating XML_
  - `tidyquant`: memungkinkan penggunaan fungsi kuantitatif pada `tidyverse`
  - `forecast`: fungsi prediksi untuk _Time Series_ dan _Linear Models_
  - `TTR`: _functions_ dan _data_ to membangun _technical trading rules_
  - `smooth`: _functions_ yang mengimplementasikan _Single Source of Error state space models_ untuk analisis _time series_ dan prediksi.
  - `shiny`: _web application framework_ yang memudahkan pembangunan aplikasi _web_ interaktif dengan R.
  - `shinydashboard`: _package_ untuk membuat _dashboard_ dengan Shiny.
  - `leaflet`: membuat _web maps_ interaktif dengan _JavaScript 'Leaflet' library_
  - `geojsonio`: konversi data dari dan ke 'GeoJSON' atau 'TopoJSON'

Instalasi dapat dilakukan dengan menggunakan perintah `install.packages(“nama library”)`.

Untuk menjalankan aplikasi, ikuti langkah berikut.
1. Jalankan _script_ `ExtractData.R` untuk mengambil (_scraping_) data gempa bumi yang pernah terjadi dari situs BMKG Indonesia. Selanjutnya, data gempa akan disimpan ke dalam beberapa _file_ dengan ekstensi `.csv` dan dibagi berdasarkan tahun terjadinya.
2. Jalankan _script_ `Predict.R` untuk melakukan prediksi berdasarkan data gempa yang telah diambil.
3. Menjalankan aplikasi prediksi gempa melalui _script_ `app.R`.

## Cara kerja
![alt text](https://raw.githubusercontent.com/haysacks/Earthquake-frequency-prediction/master/Images/flowchart.png) 
### _Web Scraping_
_Web scraping_ dilakukan untuk mengambil data gempa bumi dari situs BMKG Indonesia, dimana data tersebut berbentuk _end user output_.

Sebelum dapat masuk ke halaman situs yang menyediakan data, kita harus melakukan registrasi terlebih dahulu untuk mendapatkan _username_ dan _password_ untuk mengakses data. Registrasi dapat dilakukan dengan mengunjungi halaman [Registrasi User BMKG](http://repogempa.bmkg.go.id/signup.php).

Langkah-langkah untuk melakukan _web scraping_ dari situs BMKG Indonesia adalah sebagai berikut.
1. Pengambilan data dilakukan secara iterasi berdasarkan tahun.
2. Melakukan _login_ ke situs BMKG menggunakan _username_ dan _password_ yang didapat melalui proses registrasi sebelumnya.
3. _Session ID_ disimpan untuk pengaksesan halaman selanjutnya.
4. Mengisi parameter yang dibutuhkan oleh situs untuk mencari data gempa bumi berdasarkan parameter tersebut. Parameter yang dibutuhkan adalah tanggal awal, bulan awal, tahun awal, tanggal akhir, bulan akhir, tahun akhir, lintang atas, lintang bawah, bujur kanan, bujur kiri, magnitudo terkecil, magnitudo terbesar, kedalaman terkecil, dan kedalaman terbesar. Tahun awal dan tahun akhir diisi dengan variabel tahun, dimulai dari tahun 2008 dan diiterasi hingga tahun 2018.
5. Dikarenakan situs hanya menampilkan 100 (seratus) data gempa bumi untuk setiap halaman, maka dilakukan iterasi sebanyak halaman yang ada untuk setiap tahun yang dipilih. Pengaksesan ini dilakukan dengan melakukan _editing_ pada URL dan mengganti bagian halaman sesuai dengan iterasi halaman dengan tetap menggunakan parameter lainnya. Cara ini dimungkinkan karena terdapat pola yang sama untuk setiap halaman yang menampilkan data yang dibutuhkan pada situs. Pola tediri dari URL utama situs, halaman, ID, _session ID_ yang disimpan setelah _login_, dan parameter-parameter untuk pencarian data.
6. Melakukan inisialisasi _data frame_ untuk menyimpan data gempa bumi dalam bentuk matriks yang terdiri dari 13 kolom, yaitu `Date`, `Time`, `Latitude`, `Longitude`, `Depth`, `Mag`, `TypeMag`, `smaj`, `smin`, `az`, `rms`, `cPhase`, dan `Region`.
7. Setiap halaman disimpan dalam bentuk _HTML_. Dari _file HTML_ ini, jumlah halaman didapatkan dari baris ke 84 dengan melakukan ektraksi karakter dari _string_.

### Transformasi Data
Transformasi data diperlukan agar data yang diambil dapat digunakan untuk melakukan prediksi. Berikut merupakan tahapan transformasi data.
1. Melakukan penghapusan _header_ atau bagian lain yang tidak dibutuhkan, di luar dari data yang ingin diambil. Penghapusan ini dilakukan dengan pemotongan _code HTML_ dan hanya mengambil baris yang mengandung data yang dibutuhkan.
2. Dari hasil pemotongan _code HTML_, maka segala _HTML tags_ yang ada dihapus berdasarkan pola yang ditetapkan sehingga hanya tersisa data yang dibutuhkan untuk setiap barisnya.
3. Memasukkan data yang terdapat dalam _file HTML_ ke _data frame_ dengan melakukan iterasi untuk setiap barisnya. Setiap baris dalam tabel dijadikan sebuah _data frame_ yang terpisah yang hanya memiliki satu baris data.
4. Melakukan _export data frame_ ke dalam _file_ dengan ekstensi `.csv` untuk digunakan dalam pemodelan data pada tahap selanjutnya.

### Perhitungan Prediksi dengan _Time Series Analysis_
Prediksi dilakukan dengan memodelkan data menggunakan _Moving Average_ orde 1 dikarenakan _Autocorrelation function_ (ACF) dari data mempunyai nilai tidak signifikan setelah _lag 1_. Model ini juga dapat digunakan karena data tersebut bersifat _stationary_ yang dapat dilihat dari nilai ACF yang konvergen ke-0 ketika nilai _lag_ bertambah. Metode ini juga menghasilkan nilai _error_ paling kecil ketika melakukan _cross validation_ pada data.

Rumus dari model _Moving Average_ Orde 1:

![equation](https://latex.codecogs.com/gif.latex?x_%7Bt%7D%20%3D%20%5Cmu%20&plus;%20w_%7Bt%7D%20&plus;%20%5CTheta_%7B1%7Dw_%7Bt-1%7D)

Berikut merupakan tahapan untuk melakukan prediksi.
1. Mengubah data `.csv` yang didapatkan dari _web scraping_ menjadi satu _data frame_ untuk semua tahun.
2. Melakukan _filter_ pada data gempa bumi dengan rentang waktu dan magnitudo tertentu
3. Melakukan pemetaan wilayah yang terdapat dalam data ke wilayah yang akan ditampilkan dalam peta. Wilayah yang ditampilkan pada peta merupakan wilayah darat saja.
4. Melakukan _filter_ data gempa bumi di setiap daerah yang akan ditampilkan pada peta dengan menggunakan iterasi
5. Dikarenakan data yang digunakan berbentuk _time series_, maka diperlukan penambahan nilai 0 untuk hari yang tidak terjadi gempa agar pada minggu yang tidak terjadi, tetap dapat dimasukkan ke dalam data _time series_-nya agar intervalnya tetap.
6. Melakukan pengelompokkan data gempa untuk mendapat frekuensi mingguan dan menghilangkan nilai _outlier_.
7. Melakukan prediksi data dengan menggunakan akumulasi dari data sebelumnya sebagai _training data_. Cara yang digunakan adalah dengan menggunakan fungsi `forecast()` untuk model _Moving Average_ orde 1.
8. Melakukan pengujian data untuk menghitung _error_ dengan membandingkan data frekuensi hasil prediksi dan data frekuensi terjadinya gempa pada waktu yang lalu. Data ini berlaku sebagai _testing data_.
9. Semua data frekuensi untuk setiap daerah digabung menjadi satu _data frame_ yang disimpan ke dalam _file_ dengan ekstensi `.rds` dan digunakan untuk visualisasi.

### Visualisasi data
Visualisasi data dilakukan dengan menggunakan aplikasi Shiny. Hasil dari visualisasi prediksi frekuensi gempa bergantung pada _input_ rentang waktu yang ditentukan pengguna. Rentang waktu yang dapat dipilih adalah 52 minggu dari akhir data _historical_. Prediksi frekuensi gempa ditampilkan pada peta Indonesia yang terdapat dalam aplikasi.

Berikut merupakan isi dari tampilan aplikasi Shiny yang dibuat.
- _Dropdown_ "Display" untuk memilih mode tampilan data yang terdiri dari _Historical_ dan _Prediction_. Mode _Historical_ digunakan untuk menampilkan frekuensi gempa yang telah terjadi pada peta. Mode _Prediction_ digunakan untuk menampilkan hasil prediksi frekuensi gempa pada peta.
- _Dropdown_ "Year" untuk memilih tahun yang akan ditampilkan riwayat atau hasil prediksinya pada peta.
- _Slider_ "Week" untuk memilih minggu yang akan ditampilkan riwayat atau hasil prediksinya pada peta.
- Grafik garis yang menampilkan data _historical_ (garis merah) dan data hasil prediksi (garis hitam).
- Nilai _error_ dari hasil prediksi berdasarkan wilayah yang dipilih, terdiri dari ME (_Mean Error_), RMSE (_Root Mean Square Error_), dan MAE (_Mean Absolute Error_).
- _Choropleth map_ untuk menampilkan peta yang telah diarahkan ke wilayah Indonesia dan terdapat pembagian wilayah berdasarkan data gempa. Setiap wilayah memiliki intensitas warna yang berbeda-beda berdasarkan frekuensi gempa pada wilayah tersebut dan waktu yang dipilih. Keterangan hubungan intensitas warna dengan frekuensi gempa diletakkan pada bagian kanan bawah peta.

![alt text](https://raw.githubusercontent.com/haysacks/Earthquake-frequency-prediction/master/Images/screenshot.JPG)

## Saran pengembangan
- Menggunakan faktor-faktor lain untuk memprediksi gempa, sehingga prediksi dapat lebih akurat.
- Memprediksi gempa yang terjadi di luar Indonesia.
