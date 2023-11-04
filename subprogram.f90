module subprogram
  use, intrinsic :: iso_fortran_env
  use constants, only: PI
  implicit none

contains
  subroutine solve(A, b, x, info)
    ! Ax=bの方程式を解き, xに結果を代入し, infoにステータスを保存する.
    real(real64), INTENT(IN) :: A(:, :), b(:, :)
    real(real64), allocatable, INTENT(INOUT) :: x(:, :)
    integer(int32), INTENT(OUT) :: info
    integer(int32), allocatable :: ipiv(:)
    integer(int32) :: an, am, bn, bm
    ! Aが正方であるかチェック
    an = size(A, 1)
    am = size(A, 2)
    if (an /= am) then
      print *, 'Error : solve (an not equal to am) : an=', an, ", am=", am
      return
    end if
    ! 基本的にbmは1であることを想定する.
    bn = size(b, 1)
    bm = size(b, 2)

    if (allocated(x)) deallocate (x)
    allocate (x, source=b)
    ! ピボット行列（入れ替えた結果を保存する行列. Aと同サイズの一次元配列とする）
    allocate (ipiv(an))

    call dgesv(an, bm, A, an, ipiv, x, bn, info)  ! lapackのサブルーチンを呼び出して解く.
    if (info /= 0) then
      ! infoが0でなければbad statusなのでその旨を表示する
      WRITE (*, *) 'Error : solve : info=', info
      RETURN
    end if
  end subroutine

  function integral_trapezoidal(x, points, q_array, u_array) result(retval)
    ! 台形公式を用いて周回積分を行う.
    ! 添字1とN+1の点が一致していることを利用して,
    ! すべての点を一回ずつ足してh/2をかける代わりにhをかけることにする.
    implicit none
    real(real64) :: x(2), points(:, :), q_array(:, :), u_array(:, :)
    real(real64) :: h
    real(real64) :: retval
    integer(int32) :: points_num, i

    retval = 0.0d0
    points_num = size(points, 1)
    h = 2.0d0*PI/real(points_num, real64)
    do i = 1, points_num
      ! 一重層ポテンシャル
      ! q_arrayは添字1を書いているが配列の大きさ1なので特に意味はない.
      retval = retval + fund_gamma(x, points(i, :))*q_array(i, 1)
      ! 二重層ポテンシャル
      retval = retval - fund_gamma_derivative(x, points(i, :))*u_array(i, 1)
    end do
    retval = retval*h
  end function integral_trapezoidal

  function exact_u(x) result(retval)
    ! 与えられた点に対してx^3 - 3xy^2の厳密な値を計算する.
    implicit none
    real(real64) :: x(2)
    real(real64) :: retval

    retval = x(1)**3 - 3*x(1)*x(2)**2
  end function exact_u

  function exact_u_normal_drv(x) result(retval)
    ! 半径1の単位円の領域とする.
    ! 与えられた点に対してx^3-3xy^2の法線微分を計算する.
    implicit none
    real(real64) :: x(2)
    real(real64) :: retval
    real(real64) :: theta

    theta = atan2(x(2), x(1))
    retval = 3*(x(1)**2 - x(2)**2)*cos(theta) - 6*x(1)*x(2)*sin(theta)
  end function exact_u_normal_drv

  function fund_gamma(x, y) result(retval)
    ! 任意の二点に対する（二次元）基本解の値を返す.
    implicit none
    real(real64) :: x(2), y(2)
    real(real64) :: retval

    retval = -log(sqrt(dot_product(x - y, x - y)))/2.0d0/PI
  end function fund_gamma

  function fund_gamma_derivative(x, y) result(retval)
    ! 任意の二点（ただしyは境界上）に対する基本解のyについての法線微分を返す.
    implicit none
    real(real64) :: x(2), y(2), theta
    real(real64) :: retval

    theta = atan2(y(2), y(1))
    retval = dot_product(x - y, [cos(theta), sin(theta)])/2.0d0/PI/dot_product(x - y, x - y)
  end function fund_gamma_derivative

  subroutine component_values(m, n, edge_points, lX1, lX2, lY1, lY2, r1, r2, h, theta)
    implicit none
    integer(int32), intent(in) :: m, n
    real(real64), intent(in) :: edge_points(:, :)
    real(real64), intent(out) :: lX1, lX2, lY1, lY2, r1, r2, h, theta
    integer(int32) :: points_num
    real(real64) :: x(2), x1(2), x2(2)
    real(real64) :: t_vec(2), n_vec(2)

    ! pointsのサイズを保存
    points_num = size(edge_points, 1)

    ! moduloを用いて周期的に添え字を扱って配列外参照が起きないようにする
    ! m番目の区間の中点
    x(:) = (edge_points(modulo(m - 1, points_num) + 1, :) + edge_points(modulo(m, points_num) + 1, :))/2.0d0
    ! n番目の区間の端点
    x1(:) = edge_points(modulo(n - 1, points_num) + 1, :)
    x2(:) = edge_points(modulo(n, points_num) + 1, :)

    ! 概ね小林本の表式に合わせ, XやYを導入している.
    h = sqrt(dot_product(x1 - x2, x1 - x2))  ! 区間の長さ

    t_vec(:) = [(x2(1) - x1(1))/h, (x2(2) - x1(2))/h]
    n_vec(:) = [(x1(2) - x2(2))/h, (x2(1) - x1(1))/h]

    lX1 = dot_product(x - x1, t_vec)
    lX2 = dot_product(x - x2, t_vec)
    r1 = sqrt(dot_product(x - x1, x - x1))
    r2 = sqrt(dot_product(x - x2, x - x2))
    lY1 = dot_product(x - x1, n_vec)
    lY2 = dot_product(x - x2, n_vec)
    theta = atan2(lY2, lX2) - atan2(lY1, lX1)
  end subroutine component_values

  function U_component(m, n, edge_points) result(retval)
    ! 任意の点xと区間端点x1,x2を入力すると基本解の値を返す
    implicit none
    integer(int32) :: m, n
    real(real64) :: edge_points(:, :)
    real(real64) :: retval
    real(real64) :: lX1, lX2, lY1, lY2, r1, r2, h, theta

    call component_values(m, n, edge_points, lX1, lX2, lY1, lY2, r1, r2, h, theta)
    if (m == n) then
      ! m=nの場合は例外的な計算
      retval = (1 - log(h/2.0d0))*h/2.0d0/PI
      return
    end if

    retval = (lX2*log(r2) - lX1*log(r1) + h - lY1*theta)/2.0d0/PI
  end function U_component

  function W_component(m, n, edge_points) result(retval)
    ! 基本解の法線微分の値を計算する.
    implicit none
    integer(int32) :: m, n
    real(real64) :: edge_points(:, :)
    real(real64) :: retval
    real(real64) :: lX1, lX2, lY1, lY2, r1, r2, h, theta

    if (m == n) then
      retval = 0.5d0
      return
    end if
    call component_values(m, n, edge_points, lX1, lX2, lY1, lY2, r1, r2, h, theta)

    retval = theta/2.0d0/PI
  end function W_component

end module subprogram